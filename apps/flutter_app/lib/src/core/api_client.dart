import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_transport.dart' as auth_transport;
import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    this.neonAuthUrlOverride,
    this.apiBaseUrlOverride,
  }) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final String? neonAuthUrlOverride;
  final String? apiBaseUrlOverride;

  String get neonAuthUrl => neonAuthUrlOverride ?? AppConfig.neonAuthUrl;
  String get apiBaseUrl => apiBaseUrlOverride ?? AppConfig.apiBaseUrl;

  String get neonAuthBase {
    final url = neonAuthUrl;
    final trimmed = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    if (trimmed.isEmpty || trimmed.endsWith('/auth')) return trimmed;
    return '$trimmed/auth';
  }

  Future<AuthSession> signInWithNeon({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw ApiException('Email and password are required.', 400);
    }

    if (neonAuthUrl.isEmpty) {
      throw ApiException('NEON_AUTH_URL is not configured for this build.', 400);
    }

    auth_transport.clearAuthCookies();

    final Map<String, Object?> tokenResponse;
    try {
      await auth_transport.postAuthJson(
        Uri.parse('$neonAuthBase/sign-in/email'),
        {'email': normalizedEmail, 'password': password},
        httpClient: _httpClient,
      );

      tokenResponse = await auth_transport.getAuthJson(
        Uri.parse('$neonAuthBase/token'),
        httpClient: _httpClient,
      );
    } on auth_transport.AuthTransportException catch (exception) {
      throw ApiException(exception.message, exception.statusCode);
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      if (exception is ApiException) rethrow;
      throw ApiException('Unable to connect to authentication service. Please try again.', 503);
    }

    final token = tokenResponse['token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('Authentication token was not issued.', 401);
    }
    return currentUser(bearerToken: token);
  }

  void Function(String newToken)? onTokenRefreshed;
  void Function()? onSessionExpired;

  Future<String?>? _inFlightRefresh;

  Future<String?> refreshToken() async {
    if (neonAuthUrl.isEmpty) return null;
    if (_inFlightRefresh != null) {
      return _inFlightRefresh;
    }
    final future = _performRefreshToken();
    _inFlightRefresh = future;
    try {
      return await future;
    } finally {
      _inFlightRefresh = null;
    }
  }

  Future<String?> _performRefreshToken() async {
    try {
      final tokenResponse = await auth_transport.getAuthJson(
        Uri.parse('$neonAuthBase/token'),
        httpClient: _httpClient,
      );
      final token = tokenResponse['token'] as String?;
      if (token != null && token.isNotEmpty) {
        onTokenRefreshed?.call(token);
        return token;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<http.Response> _sendWithRetry({
    required Future<http.Response> Function(String? token) request,
    String? bearerToken,
  }) async {
    http.Response response;
    try {
      response = await request(bearerToken);
    } on http.ClientException {
      // First attempt encountered a transient browser fetch / preflight / network glitch.
      // Wait a short moment and retry once.
      await Future.delayed(const Duration(milliseconds: 350));
      response = await request(bearerToken);
    }

    if (response.statusCode == 401 && bearerToken != null) {
      final newToken = await refreshToken();
      if (newToken != null) {
        try {
          return await request(newToken);
        } on http.ClientException {
          await Future.delayed(const Duration(milliseconds: 350));
          return await request(newToken);
        }
      } else {
        onSessionExpired?.call();
      }
    }
    return response;
  }

  Future<void> signOutWithNeon() async {
    if (neonAuthUrl.isEmpty) return;
    try {
      await auth_transport.postAuth(
        Uri.parse('$neonAuthBase/sign-out'),
        httpClient: _httpClient,
      );
    } on auth_transport.AuthTransportException {
      // Local session cleanup should still proceed if the remote session is already gone.
    } catch (_) {
      // Ignore network errors during sign-out
    } finally {
      auth_transport.clearAuthCookies();
    }
  }

  Future<AuthSession> currentUser({String? bearerToken, AuthSession? devSession}) async {
    final json = await getJson('/api/v1/me', bearerToken: bearerToken, devSession: devSession);
    return AuthSession(
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      roles: ((json['roles'] as List?) ?? const [])
          .map((role) => AppRole.values.byName(role as String))
          .toList(),
      schoolId: json['schoolId'] as String,
      bearerToken: bearerToken,
      devNeonUserId: devSession?.devNeonUserId,
    );
  }

  Future<Map<String, Object?>> getJson(
    String path, {
    String? bearerToken,
    AuthSession? devSession,
    AuthSession? session,
  }) async {
    final initialToken = bearerToken ?? session?.bearerToken;
    final dev = devSession ?? (session?.devNeonUserId != null ? session : null);
    try {
      final response = await _sendWithRetry(
        bearerToken: initialToken,
        request: (token) => _httpClient.get(
          Uri.parse('$apiBaseUrl$path'),
          headers: _headers(bearerToken: token, devSession: dev),
        ),
      );
      _ensureSuccess(response);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
  }

  Future<List<Map<String, Object?>>> getList(
    String path, {
    required AuthSession session,
    Map<String, String>? queryParameters,
  }) async {
    try {
      final baseUri = Uri.parse('$apiBaseUrl$path');
      final uri = queryParameters != null && queryParameters.isNotEmpty
          ? baseUri.replace(queryParameters: {...baseUri.queryParameters, ...queryParameters})
          : baseUri;
      final response = await _sendWithRetry(
        bearerToken: session.bearerToken,
        request: (token) => _httpClient.get(
          uri,
          headers: _headers(bearerToken: token, devSession: session),
        ),
      );
      _ensureSuccess(response);
      return (_decodeList(response)).cast<Map<String, Object?>>();
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
  }

  Future<Map<String, Object?>> postJson(
    String path,
    Map<String, Object?> body, {
    required AuthSession session,
  }) async {
    try {
      final response = await _sendWithRetry(
        bearerToken: session.bearerToken,
        request: (token) => _httpClient.post(
          Uri.parse('$apiBaseUrl$path'),
          headers: _headers(bearerToken: token, devSession: session),
          body: jsonEncode(body),
        ),
      );
      _ensureSuccess(response);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
  }

  Future<List<Map<String, Object?>>> postList(
    String path,
    Map<String, Object?> body, {
    required AuthSession session,
  }) async {
    try {
      final response = await _sendWithRetry(
        bearerToken: session.bearerToken,
        request: (token) => _httpClient.post(
          Uri.parse('$apiBaseUrl$path'),
          headers: _headers(bearerToken: token, devSession: session),
          body: jsonEncode(body),
        ),
      );
      _ensureSuccess(response);
      return _decodeList(response)
          .whereType<Map<String, Object?>>()
          .toList();
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
  }


  Future<Map<String, Object?>> createFeePaymentOrder({
    required AuthSession session,
    required String allocationId,
    required int amount,
    String? returnUrl,
  }) async {
    return postJson(
      '/api/v1/portal/fees/orders',
      {
        'allocationId': allocationId,
        'amount': amount,
        'returnUrl': ?returnUrl,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> verifyFeePaymentOrder({
    required AuthSession session,
    required String orderId,
  }) async {
    return postJson(
      '/api/v1/portal/fees/verify',
      {'orderId': orderId},
      session: session,
    );
  }

  Future<Map<String, Object?>> uploadAdmissionDocument({
    required AuthSession session,
    required String applicationId,
    required String documentId,
    required List<int> bytes,
    required String fileName,
    String? contentType,
  }) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/api/v1/admin/admissions/applications/$applicationId/documents/$documentId/upload');
      final request = http.MultipartRequest('POST', uri);
      final headers = _headers(bearerToken: session.bearerToken, devSession: session);
      headers.remove('content-type');
      request.headers.addAll(headers);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      _ensureSuccess(response);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to upload document file.', 500);
    }
  }

  Future<List<int>> downloadAdmissionDocument({
    required AuthSession session,
    required String applicationId,
    required String documentId,
  }) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/api/v1/admin/admissions/applications/$applicationId/documents/$documentId/download');
      final response = await _sendWithRetry(
        bearerToken: session.bearerToken,
        request: (token) => _httpClient.get(
          uri,
          headers: _headers(bearerToken: token, devSession: session),
        ),
      );
      _ensureSuccess(response);
      return response.bodyBytes;
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to download document file.', 500);
    }
  }

  Future<Map<String, Object?>> deleteAdmissionDocumentFile({
    required AuthSession session,
    required String documentId,
  }) async {
    return deleteJson('/api/v1/admin/admissions/documents/$documentId/file', session: session);
  }

  Future<Map<String, Object?>> putJson(
    String path,
    Map<String, Object?> body, {
    required AuthSession session,
  }) async {
    try {
      final response = await _sendWithRetry(
        bearerToken: session.bearerToken,
        request: (token) => _httpClient.put(
          Uri.parse('$apiBaseUrl$path'),
          headers: _headers(bearerToken: token, devSession: session),
          body: jsonEncode(body),
        ),
      );
      _ensureSuccess(response);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
  }

  Future<Map<String, Object?>> patchJson(
    String path,
    Map<String, Object?> body, {
    required AuthSession session,
  }) async {
    try {
      final response = await _sendWithRetry(
        bearerToken: session.bearerToken,
        request: (token) => _httpClient.patch(
          Uri.parse('$apiBaseUrl$path'),
          headers: _headers(bearerToken: token, devSession: session),
          body: jsonEncode(body),
        ),
      );
      _ensureSuccess(response);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
  }

  Future<Map<String, Object?>> deleteJson(String path, {required AuthSession session}) async {
    try {
      final response = await _sendWithRetry(
        bearerToken: session.bearerToken,
        request: (token) => _httpClient.delete(
          Uri.parse('$apiBaseUrl$path'),
          headers: _headers(bearerToken: token, devSession: session),
        ),
      );
      _ensureSuccess(response);
      return _decode(response);
    } on ApiException {
      rethrow;
    } on http.ClientException catch (exception) {
      throw ApiException('Network connection error: ${exception.message}', 503);
    } catch (exception) {
      throw ApiException('Failed to communicate with Schoolic API.', 500);
    }
  }

  // Phase 10: Bulk Import
  Future<Map<String, Object?>> previewBulkImport({
    required AuthSession session,
    required String entity,
    required String csv,
  }) async {
    return postJson(
      '/api/v1/admin/imports/preview',
      {'entity': entity, 'csv': csv},
      session: session,
    );
  }

  Future<Map<String, Object?>> commitBulkImport({
    required AuthSession session,
    required String entity,
    required List<Map<String, Object?>> records,
    String? academicYearId,
    String? defaultClassId,
    String? defaultSectionId,
  }) async {
    return postJson(
      '/api/v1/admin/imports/commit',
      {
        'entity': entity,
        'records': records,
        'academicYearId': ?academicYearId,
        'defaultClassId': ?defaultClassId,
        'defaultSectionId': ?defaultSectionId,
      },
      session: session,
    );
  }

  // Phase 10: Onboarding Wizard
  Future<Map<String, Object?>> getOnboardingStatus({
    required AuthSession session,
  }) async {
    return getJson('/api/v1/admin/onboarding/status', session: session);
  }

  Future<Map<String, Object?>> runOnboardingWizard({
    required AuthSession session,
    required String schoolName,
    required String academicYearName,
    required String startDate,
    required String endDate,
    required List<Map<String, Object?>> classes,
  }) async {
    return postJson(
      '/api/v1/admin/onboarding/wizard',
      {
        'schoolName': schoolName,
        'academicYearName': academicYearName,
        'startDate': startDate,
        'endDate': endDate,
        'classes': classes,
      },
      session: session,
    );
  }

  // Phase 10: Notifications
  Future<List<Map<String, Object?>>> listNotifications({
    required AuthSession session,
    String? channel,
    String? status,
  }) async {
    final params = <String, String>{
      'channel': ?channel,
      'status': ?status,
    };
    return getList(
      '/api/v1/admin/notifications',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> sendNotification({
    required AuthSession session,
    required String channel,
    required String title,
    required String body,
    String? recipientPhone,
    String? recipientEmail,
    String? recipientUserId,
    Map<String, Object?>? data,
  }) async {
    return postJson(
      '/api/v1/admin/notifications/send',
      {
        'channel': channel,
        'title': title,
        'body': body,
        'recipientPhone': ?recipientPhone,
        'recipientEmail': ?recipientEmail,
        'recipientUserId': ?recipientUserId,
        'data': ?data,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> triggerFeeReminders({
    required AuthSession session,
    int days = 7,
  }) async {
    return postJson(
      '/api/v1/admin/notifications/trigger-fee-reminders?days=$days',
      {},
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getPortalNotifications({
    required AuthSession session,
  }) async {
    return getList('/api/v1/portal/notifications', session: session);
  }

  // Phase 10: Teacher Availability & Messaging
  Future<Map<String, Object?>> getTeacherAvailability({
    required AuthSession session,
  }) async {
    return getJson('/api/v1/teacher/availability', session: session);
  }

  Future<Map<String, Object?>> updateTeacherAvailability({
    required AuthSession session,
    required String startTime,
    required String endTime,
    required String availableDays,
    required String autoReplyMessage,
    required bool isEnabled,
  }) async {
    return putJson(
      '/api/v1/teacher/availability',
      {
        'startTime': startTime,
        'endTime': endTime,
        'availableDays': availableDays,
        'autoReplyMessage': autoReplyMessage,
        'isEnabled': isEnabled,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> listChatConversations({
    required AuthSession session,
    bool isPortal = false,
  }) async {
    final prefix = isPortal ? '/api/v1/portal' : '/api/v1/teacher';
    return getList('$prefix/chat/conversations', session: session);
  }

  Future<Map<String, Object?>> createChatConversation({
    required AuthSession session,
    required String studentId,
    required String teacherStaffId,
    required String subject,
    String? initialMessage,
  }) async {
    return postJson(
      '/api/v1/portal/chat/conversations',
      {
        'studentId': studentId,
        'teacherStaffId': teacherStaffId,
        'subject': subject,
        'initialMessage': ?initialMessage,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> listChatMessages({
    required AuthSession session,
    required String conversationId,
    bool isPortal = false,
  }) async {
    final prefix = isPortal ? '/api/v1/portal' : '/api/v1/teacher';
    return getJson('$prefix/chat/conversations/$conversationId/messages', session: session);
  }

  Future<Map<String, Object?>> sendChatMessage({
    required AuthSession session,
    required String conversationId,
    required String content,
    bool isPortal = false,
  }) async {
    final prefix = isPortal ? '/api/v1/portal' : '/api/v1/teacher';
    return postJson(
      '$prefix/chat/conversations/$conversationId/messages',
      {'content': content},
      session: session,
    );
  }

  // Phase 11: Enterprise RBAC & DPDP Compliance
  Future<List<Map<String, Object?>>> listAuditLogs({
    required AuthSession session,
    String? action,
    String? resourceType,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'action': ?action,
      'resourceType': ?resourceType,
      'limit': limit.toString(),
    };
    return getList(
      '/api/v1/admin/audit-logs',
      session: session,
      queryParameters: params,
    );
  }

  Future<List<Map<String, Object?>>> listDpdpConsents({
    required AuthSession session,
    String? studentId,
    String? status,
  }) async {
    final params = <String, String>{
      'studentId': ?studentId,
      'status': ?status,
    };
    return getList(
      '/api/v1/admin/dpdp/consents',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> recordDpdpConsent({
    required AuthSession session,
    required String studentId,
    required String parentGuardianName,
    required String parentGuardianPhone,
    required String consentType,
    String verifiedVia = 'portal_submission',
    String? validUntil,
  }) async {
    return postJson(
      '/api/v1/admin/dpdp/consents',
      {
        'studentId': studentId,
        'parentGuardianName': parentGuardianName,
        'parentGuardianPhone': parentGuardianPhone,
        'consentType': consentType,
        'verifiedVia': verifiedVia,
        'validUntil': ?validUntil,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> listDsrRequests({
    required AuthSession session,
    String? status,
  }) async {
    final params = <String, String>{
      'status': ?status,
    };
    return getList(
      '/api/v1/admin/dpdp/dsr',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> resolveDsrRequest({
    required AuthSession session,
    required String requestId,
    required String status,
    required String resolutionNotes,
    bool? anonymizeStudent,
  }) async {
    return putJson(
      '/api/v1/admin/dpdp/dsr/$requestId',
      {
        'status': status,
        'resolutionNotes': resolutionNotes,
        'anonymizeStudent': ?anonymizeStudent,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> submitPortalDsrRequest({
    required AuthSession session,
    String? studentId,
    required String requestType,
    required String reason,
  }) async {
    return postJson(
      '/api/v1/portal/dpdp/dsr',
      {
        'studentId': ?studentId,
        'requestType': requestType,
        'reason': reason,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> listPortalDsrRequests({
    required AuthSession session,
  }) async {
    return getList('/api/v1/portal/dpdp/dsr', session: session);
  }

  Future<Map<String, Object?>> assignSectionClassTeacher({
    required AuthSession session,
    required String sectionId,
    String? classTeacherStaffId,
  }) async {
    return putJson(
      '/api/v1/admin/sections/$sectionId/class-teacher',
      {'classTeacherStaffId': classTeacherStaffId},
      session: session,
    );
  }

  // Phase 11: Financial Depth (Concessions, Refunds, Heads)
  Future<List<Map<String, Object?>>> listFeeConcessions({
    required AuthSession session,
  }) async {
    return getList('/api/v1/admin/fees/concessions', session: session);
  }

  Future<Map<String, Object?>> createFeeConcession({
    required AuthSession session,
    required String name,
    required String code,
    required String type,
    required int value,
    required String category,
  }) async {
    return postJson(
      '/api/v1/admin/fees/concessions',
      {
        'name': name,
        'code': code,
        'type': type,
        'value': value,
        'category': category,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> applyStudentConcession({
    required AuthSession session,
    required String studentId,
    required String allocationId,
    required String concessionId,
    String? reason,
  }) async {
    return postJson(
      '/api/v1/admin/fees/concessions/apply',
      {
        'studentId': studentId,
        'allocationId': allocationId,
        'concessionId': concessionId,
        'reason': ?reason,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> listStudentConcessions({
    required AuthSession session,
    String? studentId,
    String? allocationId,
  }) async {
    final params = <String, String>{
      'studentId': ?studentId,
      'allocationId': ?allocationId,
    };
    return getList(
      '/api/v1/admin/fees/concessions/applied',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<List<Map<String, Object?>>> listFeeRefunds({
    required AuthSession session,
    String? status,
  }) async {
    final params = <String, String>{
      'status': ?status,
    };
    return getList(
      '/api/v1/admin/fees/refunds',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> createFeeRefund({
    required AuthSession session,
    required String allocationId,
    required String studentId,
    String? paymentId,
    required int amount,
    required String reason,
    String mode = 'bank_transfer',
    String? referenceNumber,
  }) async {
    return postJson(
      '/api/v1/admin/fees/refunds',
      {
        'allocationId': allocationId,
        'studentId': studentId,
        'paymentId': ?paymentId,
        'amount': amount,
        'reason': reason,
        'mode': mode,
        'referenceNumber': ?referenceNumber,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> updateFeeRefundStatus({
    required AuthSession session,
    required String refundId,
    required String status,
  }) async {
    return putJson(
      '/api/v1/admin/fees/refunds/$refundId/status',
      {'status': status},
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> listFeeStructureHeads({
    required AuthSession session,
    required String feeStructureId,
  }) async {
    return getList('/api/v1/admin/fees/structures/$feeStructureId/heads', session: session);
  }

  Future<Map<String, Object?>> createFeeStructureHead({
    required AuthSession session,
    required String feeStructureId,
    required String headName,
    required int amount,
    bool isOptional = false,
  }) async {
    return postJson(
      '/api/v1/admin/fees/structures/$feeStructureId/heads',
      {
        'headName': headName,
        'amount': amount,
        'isOptional': isOptional,
      },
      session: session,
    );
  }

  // --- Phase 12: Operations (Leaves, Transport, Certificates, Calendar & PTM) ---

  // 1. Leaves
  Future<List<Map<String, Object?>>> getStudentLeaves({
    required AuthSession session,
    String? studentId,
    String? status,
  }) async {
    final params = <String, String>{
      'studentId': ?studentId,
      if (status != null && status != 'all') 'status': status,
    };
    return getList(
      '/api/v1/admin/leaves/students',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> reviewStudentLeave({
    required AuthSession session,
    required String leaveId,
    required String status,
    String? reviewerNotes,
  }) async {
    return putJson(
      '/api/v1/admin/leaves/students/$leaveId/status',
      {
        'status': status,
        'reviewerNotes': ?reviewerNotes,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getStaffLeaves({
    required AuthSession session,
    String? staffId,
    String? status,
  }) async {
    final params = <String, String>{
      'staffId': ?staffId,
      if (status != null && status != 'all') 'status': status,
    };
    return getList(
      '/api/v1/admin/leaves/staff',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> createStaffLeave({
    required AuthSession session,
    String? staffId,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    return postJson(
      '/api/v1/admin/leaves/staff',
      {
        'staffId': ?staffId,
        'leaveType': leaveType,
        'startDate': startDate,
        'endDate': endDate,
        'reason': reason,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> reviewStaffLeave({
    required AuthSession session,
    required String leaveId,
    required String status,
    String? reviewerNotes,
  }) async {
    return putJson(
      '/api/v1/admin/leaves/staff/$leaveId/status',
      {
        'status': status,
        'reviewerNotes': ?reviewerNotes,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getStaffLeaveSubstitutes({
    required AuthSession session,
    required String leaveId,
  }) async {
    return getList('/api/v1/admin/leaves/staff/$leaveId/substitutes', session: session);
  }

  // 2. Transport
  Future<List<Map<String, Object?>>> getTransportVehicles({required AuthSession session}) async {
    return getList('/api/v1/admin/transport/vehicles', session: session);
  }

  Future<Map<String, Object?>> createTransportVehicle({
    required AuthSession session,
    required String vehicleNumber,
    required String model,
    required int capacity,
    String? gpsDeviceId,
    String? insuranceExpiry,
    String? fitnessExpiry,
    String status = 'active',
  }) async {
    return postJson(
      '/api/v1/admin/transport/vehicles',
      {
        'vehicleNumber': vehicleNumber,
        'model': model,
        'capacity': capacity,
        'gpsDeviceId': ?gpsDeviceId,
        'insuranceExpiry': ?insuranceExpiry,
        'fitnessExpiry': ?fitnessExpiry,
        'status': status,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getTransportDrivers({required AuthSession session}) async {
    return getList('/api/v1/admin/transport/drivers', session: session);
  }

  Future<Map<String, Object?>> createTransportDriver({
    required AuthSession session,
    required String fullName,
    required String phone,
    required String licenseNumber,
    String? licenseExpiry,
    String status = 'active',
  }) async {
    return postJson(
      '/api/v1/admin/transport/drivers',
      {
        'fullName': fullName,
        'phone': phone,
        'licenseNumber': licenseNumber,
        'licenseExpiry': ?licenseExpiry,
        'status': status,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getTransportRoutes({required AuthSession session}) async {
    return getList('/api/v1/admin/transport/routes', session: session);
  }

  Future<Map<String, Object?>> createTransportRoute({
    required AuthSession session,
    required String routeNumber,
    required String routeName,
    required String startPoint,
    required String endPoint,
    String? vehicleId,
    String? driverId,
    String status = 'active',
  }) async {
    return postJson(
      '/api/v1/admin/transport/routes',
      {
        'routeNumber': routeNumber,
        'routeName': routeName,
        'startPoint': startPoint,
        'endPoint': endPoint,
        'vehicleId': ?vehicleId,
        'driverId': ?driverId,
        'status': status,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getTransportStops({
    required AuthSession session,
    required String routeId,
  }) async {
    return getList('/api/v1/admin/transport/routes/$routeId/stops', session: session);
  }

  Future<Map<String, Object?>> createTransportStop({
    required AuthSession session,
    required String routeId,
    required String stopName,
    required String pickupTime,
    required String dropTime,
    int stopOrder = 1,
    int monthlyFeeAmount = 0,
    String? latitude,
    String? longitude,
  }) async {
    return postJson(
      '/api/v1/admin/transport/stops',
      {
        'routeId': routeId,
        'stopName': stopName,
        'pickupTime': pickupTime,
        'dropTime': dropTime,
        'stopOrder': stopOrder,
        'monthlyFeeAmount': monthlyFeeAmount,
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getTransportAllocations({
    required AuthSession session,
    String? studentId,
    String? routeId,
  }) async {
    final params = <String, String>{
      'studentId': ?studentId,
      'routeId': ?routeId,
    };
    return getList(
      '/api/v1/admin/transport/allocations',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> createTransportAllocation({
    required AuthSession session,
    required String studentId,
    required String routeId,
    required String stopId,
    String? academicYearId,
    String? startDate,
  }) async {
    return postJson(
      '/api/v1/admin/transport/allocations',
      {
        'studentId': studentId,
        'routeId': routeId,
        'stopId': stopId,
        'academicYearId': ?academicYearId,
        'startDate': ?startDate,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getTransportLogs({
    required AuthSession session,
    String? routeId,
    String? date,
  }) async {
    final params = <String, String>{
      'routeId': ?routeId,
      'date': ?date,
    };
    return getList(
      '/api/v1/admin/transport/logs',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> createTransportLog({
    required AuthSession session,
    required String routeId,
    String? date,
    required String tripType,
    required String status,
    String? currentStopId,
    String? notes,
  }) async {
    return postJson(
      '/api/v1/admin/transport/logs',
      {
        'routeId': routeId,
        'date': ?date,
        'tripType': tripType,
        'status': status,
        'currentStopId': ?currentStopId,
        'notes': ?notes,
      },
      session: session,
    );
  }

  // 3. Certificates
  Future<List<Map<String, Object?>>> getCertificates({
    required AuthSession session,
    String? studentId,
    String? certificateType,
  }) async {
    final params = <String, String>{
      'studentId': ?studentId,
      if (certificateType != null && certificateType != 'all') 'certificateType': certificateType,
    };
    return getList(
      '/api/v1/admin/certificates',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> issueCertificate({
    required AuthSession session,
    required String studentId,
    required String certificateType,
    String? academicYearId,
    String? issueDate,
    Map<String, Object?>? metadata,
  }) async {
    return postJson(
      '/api/v1/admin/certificates',
      {
        'studentId': studentId,
        'certificateType': certificateType,
        'academicYearId': ?academicYearId,
        'issueDate': ?issueDate,
        'metadata': ?metadata,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> revokeCertificate({
    required AuthSession session,
    required String certificateId,
    String? reason,
  }) async {
    return postJson(
      '/api/v1/admin/certificates/$certificateId/revoke',
      {
        'reason': ?reason,
      },
      session: session,
    );
  }

  // 4. Calendar & PTM
  Future<List<Map<String, Object?>>> getCalendarEvents({
    required AuthSession session,
    String? targetAudience,
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, String>{
      if (targetAudience != null && targetAudience != 'all') 'targetAudience': targetAudience,
      'startDate': ?startDate,
      'endDate': ?endDate,
    };
    return getList(
      '/api/v1/admin/calendar',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> createCalendarEvent({
    required AuthSession session,
    required String title,
    String? description,
    required String eventType,
    required String startDate,
    required String endDate,
    bool isAllDay = true,
    String targetAudience = 'all',
    String? academicYearId,
  }) async {
    return postJson(
      '/api/v1/admin/calendar',
      {
        'title': title,
        'description': ?description,
        'eventType': eventType,
        'startDate': startDate,
        'endDate': endDate,
        'isAllDay': isAllDay,
        'targetAudience': targetAudience,
        'academicYearId': ?academicYearId,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> deleteCalendarEvent({
    required AuthSession session,
    required String eventId,
  }) async {
    return deleteJson('/api/v1/admin/calendar/$eventId', session: session);
  }

  Future<List<Map<String, Object?>>> getPtmSchedules({required AuthSession session}) async {
    return getList('/api/v1/admin/ptm/schedules', session: session);
  }

  Future<Map<String, Object?>> createPtmSchedule({
    required AuthSession session,
    required String title,
    required String eventDate,
    required String startTime,
    required String endTime,
    int slotDurationMinutes = 15,
    List<String>? teacherStaffIds,
    String? academicYearId,
  }) async {
    return postJson(
      '/api/v1/admin/ptm/schedules',
      {
        'title': title,
        'eventDate': eventDate,
        'startTime': startTime,
        'endTime': endTime,
        'slotDurationMinutes': slotDurationMinutes,
        'teacherStaffIds': ?teacherStaffIds,
        'academicYearId': ?academicYearId,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getPtmSlots({
    required AuthSession session,
    String? scheduleId,
    String? teacherStaffId,
    String? studentId,
    String? status,
  }) async {
    final params = <String, String>{
      'scheduleId': ?scheduleId,
      'teacherStaffId': ?teacherStaffId,
      'studentId': ?studentId,
      if (status != null && status != 'all') 'status': status,
    };
    return getList(
      '/api/v1/admin/ptm/slots',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  // =========================================================================
  // Phase 13: Academic Depth & Board-Specific Grading Schemes
  // =========================================================================

  Future<List<Map<String, Object?>>> getGradingSchemes({
    required AuthSession session,
    String? academicYearId,
  }) async {
    final params = <String, String>{
      'academicYearId': ?academicYearId,
    };
    return getList(
      '/api/v1/admin/academics/grading-schemes',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> createGradingScheme({
    required AuthSession session,
    required String name,
    required String board,
    String? academicYearId,
    String? description,
    int? passingPercentage,
    bool? isDefault,
  }) async {
    return postJson(
      '/api/v1/admin/academics/grading-schemes',
      {
        'name': name,
        'board': board,
        'academicYearId': ?academicYearId,
        'description': ?description,
        'passingPercentage': ?passingPercentage,
        'isDefault': ?isDefault,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> seedDefaultBoardSchemes({
    required AuthSession session,
    String? academicYearId,
  }) async {
    final qs = academicYearId != null ? '?academicYearId=$academicYearId' : '';
    await postJson(
      '/api/v1/admin/academics/grading-schemes/seed-defaults$qs',
      {},
      session: session,
    );
    return getGradingSchemes(session: session, academicYearId: academicYearId);
  }

  Future<Map<String, Object?>> createGradingScale({
    required AuthSession session,
    required String schemeId,
    required String grade,
    required int minScore,
    required int maxScore,
    required String gradePoint,
    String? remarks,
    int? orderIndex,
  }) async {
    return postJson(
      '/api/v1/admin/academics/grading-schemes/scales',
      {
        'schemeId': schemeId,
        'grade': grade,
        'minScore': minScore,
        'maxScore': maxScore,
        'gradePoint': gradePoint,
        'remarks': ?remarks,
        'orderIndex': ?orderIndex,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> createEvaluationComponent({
    required AuthSession session,
    required String schemeId,
    required String name,
    required String componentType,
    required int weightagePercentage,
    required int maxMarks,
    String? term,
    int? orderIndex,
  }) async {
    return postJson(
      '/api/v1/admin/academics/grading-schemes/components',
      {
        'schemeId': schemeId,
        'name': name,
        'componentType': componentType,
        'weightagePercentage': weightagePercentage,
        'maxMarks': maxMarks,
        'term': ?term,
        'orderIndex': ?orderIndex,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> generateReportCards({
    required AuthSession session,
    required String academicYearId,
    required String classId,
    required String sectionId,
    required String schemeId,
    String? term,
    List<String>? studentIds,
    String? teacherRemarks,
  }) async {
    return postJson(
      '/api/v1/admin/academics/report-cards/generate',
      {
        'academicYearId': academicYearId,
        'classId': classId,
        'sectionId': sectionId,
        'schemeId': schemeId,
        'term': ?term,
        'studentIds': ?studentIds,
        'teacherRemarks': ?teacherRemarks,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getReportCards({
    required AuthSession session,
    String? classId,
    String? sectionId,
    String? academicYearId,
    String? studentId,
    String? term,
  }) async {
    final params = <String, String>{
      'classId': ?classId,
      'sectionId': ?sectionId,
      'academicYearId': ?academicYearId,
      'studentId': ?studentId,
      'term': ?term,
    };
    return getList(
      '/api/v1/admin/academics/report-cards',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> getReportCard({
    required AuthSession session,
    required String reportCardId,
  }) async {
    return getJson(
      '/api/v1/admin/academics/report-cards/$reportCardId',
      session: session,
    );
  }

  Future<Map<String, Object?>> publishReportCard({
    required AuthSession session,
    required String reportCardId,
    required bool isPublished,
  }) async {
    return putJson(
      '/api/v1/admin/academics/report-cards/$reportCardId/publish',
      {
        'isPublished': isPublished,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getPortalBoardReportCards({
    required AuthSession session,
    String? studentId,
  }) async {
    final params = <String, String>{
      'studentId': ?studentId,
    };
    return getList(
      '/api/v1/portal/board-report-cards',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  // =========================================================================
  // Phase 13: Offline-First Attendance Synchronization
  // =========================================================================

  Future<Map<String, Object?>> syncOfflineAttendance(
    List<Map<String, Object?>> batches, {
    required AuthSession session,
  }) async {
    return postJson(
      '/api/v1/teacher/attendance/sync',
      {
        'batches': batches,
      },
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getOfflineSyncLogs({
    required AuthSession session,
    String? staffId,
  }) async {
    final params = <String, String>{
      'staffId': ?staffId,
    };
    return getList(
      '/api/v1/admin/academics/offline-sync-logs',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  // =========================================================================
  // Phase 14: Applied AI & Enhanced Institutional UX
  // =========================================================================

  Future<List<Map<String, Object?>>> evaluateStudentRiskScores({
    required AuthSession session,
    String? academicYearId,
    String? classId,
    String? sectionId,
  }) async {
    final payload = <String, Object?>{
      'academicYearId': ?academicYearId,
      'classId': ?classId,
      'sectionId': ?sectionId,
    };
    return postList(
      '/api/v1/admin/analytics/at-risk-students/evaluate',
      payload,
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getAtRiskStudents({
    required AuthSession session,
    String? classId,
    String? sectionId,
    String? riskLevel,
    String? status,
  }) async {
    final params = <String, String>{
      if (classId != null && classId.isNotEmpty) 'classId': classId,
      if (sectionId != null && sectionId.isNotEmpty) 'sectionId': sectionId,
      if (riskLevel != null && riskLevel != 'all') 'riskLevel': riskLevel,
      if (status != null && status != 'all') 'status': status,
    };
    return getList(
      '/api/v1/admin/analytics/at-risk-students',
      session: session,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }

  Future<Map<String, Object?>> getStudentRiskAlert({
    required AuthSession session,
    required String studentId,
  }) async {
    return getJson(
      '/api/v1/admin/analytics/at-risk-students/$studentId',
      session: session,
    );
  }

  Future<Map<String, Object?>> recordStudentIntervention({
    required AuthSession session,
    required String studentId,
    required String action,
    required String notes,
    String? status,
  }) async {
    return postJson(
      '/api/v1/admin/analytics/at-risk-students/$studentId/intervene',
      {
        'action': action,
        'notes': notes,
        'status': ?status,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> executeNaturalLanguageQuery({
    required AuthSession session,
    required String query,
  }) async {
    return postJson(
      '/api/v1/admin/analytics/natural-language-query',
      {'query': query},
      session: session,
    );
  }

  Future<Map<String, Object?>> draftReportCardRemarks({
    required AuthSession session,
    required String studentName,
    required String overallPercentage,
    String? attendanceRate,
    String tone = 'encouraging',
    List<Map<String, dynamic>>? subjects,
    List<Map<String, dynamic>>? coScholastic,
  }) async {
    return postJson(
      '/api/v1/teacher/ai/draft-remarks',
      {
        'studentName': studentName,
        'overallPercentage': overallPercentage,
        'attendanceRate': ?attendanceRate,
        'tone': tone,
        'subjects': ?subjects,
        'coScholastic': ?coScholastic,
      },
      session: session,
    );
  }

  Future<Map<String, Object?>> draftHomeworkFeedback({
    required AuthSession session,
    required String assignmentTitle,
    required String subject,
    required num studentScore,
    required num maxScore,
    String? strengths,
    String? areasForImprovement,
  }) async {
    return postJson(
      '/api/v1/teacher/ai/homework-feedback',
      {
        'assignmentTitle': assignmentTitle,
        'subject': subject,
        'studentScore': studentScore,
        'maxScore': maxScore,
        'strengths': ?strengths,
        'areasForImprovement': ?areasForImprovement,
      },
      session: session,
    );
  }

  // ==========================================
  // Phase 15: Campus Operations Ecosystem
  // ==========================================

  // --- 1. Library Management ---
  Future<List<Map<String, Object?>>> getLibraryBooks({
    required AuthSession session,
    String? search,
    String? category,
  }) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (category != null && category.isNotEmpty) queryParams['category'] = category;

    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';

    return getList(
      '/api/v1/admin/operations/library/books$queryString',
      session: session,
    );
  }

  Future<Map<String, Object?>> createLibraryBook({
    required AuthSession session,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/library/books',
      payload,
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getLibraryLoans({
    required AuthSession session,
    String? status,
    String? memberType,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (memberType != null && memberType.isNotEmpty) queryParams['memberType'] = memberType;

    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';

    return getList(
      '/api/v1/admin/operations/library/loans$queryString',
      session: session,
    );
  }

  Future<Map<String, Object?>> issueLibraryLoan({
    required AuthSession session,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/library/loans/issue',
      payload,
      session: session,
    );
  }

  Future<Map<String, Object?>> returnLibraryLoan({
    required AuthSession session,
    required String loanId,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/library/loans/$loanId/return',
      payload,
      session: session,
    );
  }

  Future<Map<String, Object?>> getLibraryStats({
    required AuthSession session,
  }) async {
    return getJson(
      '/api/v1/admin/operations/library/stats',
      session: session,
    );
  }

  // --- 2. Inventory & Asset Management ---
  Future<List<Map<String, Object?>>> getInventoryItems({
    required AuthSession session,
    String? category,
    String? condition,
  }) async {
    final queryParams = <String, String>{};
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (condition != null && condition.isNotEmpty) queryParams['condition'] = condition;

    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';

    return getList(
      '/api/v1/admin/operations/inventory/items$queryString',
      session: session,
    );
  }

  Future<Map<String, Object?>> createInventoryItem({
    required AuthSession session,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/inventory/items',
      payload,
      session: session,
    );
  }

  Future<Map<String, Object?>> allocateInventoryItem({
    required AuthSession session,
    required String itemId,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/inventory/items/$itemId/allocate',
      payload,
      session: session,
    );
  }

  Future<Map<String, Object?>> returnInventoryAllocation({
    required AuthSession session,
    required String allocationId,
  }) async {
    return postJson(
      '/api/v1/admin/operations/inventory/allocations/$allocationId/return',
      {},
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getInventoryPurchaseRequests({
    required AuthSession session,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';

    return getList(
      '/api/v1/admin/operations/inventory/purchase-requests$queryString',
      session: session,
    );
  }

  Future<Map<String, Object?>> createInventoryPurchaseRequest({
    required AuthSession session,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/inventory/purchase-requests',
      payload,
      session: session,
    );
  }

  Future<Map<String, Object?>> reviewInventoryPurchaseRequest({
    required AuthSession session,
    required String requestId,
    required Map<String, Object?> payload,
  }) async {
    return putJson(
      '/api/v1/admin/operations/inventory/purchase-requests/$requestId/status',
      payload,
      session: session,
    );
  }

  // --- 3. Staff Payroll ---
  Future<List<Map<String, Object?>>> getStaffSalaryStructures({
    required AuthSession session,
  }) async {
    return getList(
      '/api/v1/admin/operations/payroll/salary-structures',
      session: session,
    );
  }

  Future<Map<String, Object?>> upsertStaffSalaryStructure({
    required AuthSession session,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/payroll/salary-structures',
      payload,
      session: session,
    );
  }

  Future<Map<String, Object?>> generateMonthlyPayroll({
    required AuthSession session,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/payroll/generate-monthly',
      payload,
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getStaffPayrollRecords({
    required AuthSession session,
    int? month,
    int? year,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';

    return getList(
      '/api/v1/admin/operations/payroll/records$queryString',
      session: session,
    );
  }

  Future<Map<String, Object?>> markPayrollPaid({
    required AuthSession session,
    required String recordId,
    required Map<String, Object?> payload,
  }) async {
    return putJson(
      '/api/v1/admin/operations/payroll/records/$recordId/mark-paid',
      payload,
      session: session,
    );
  }

  // --- 4. Hostel & Visitor Management ---
  Future<List<Map<String, Object?>>> getHostelRooms({
    required AuthSession session,
    String? roomType,
  }) async {
    final queryParams = <String, String>{};
    if (roomType != null && roomType.isNotEmpty) queryParams['roomType'] = roomType;

    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';

    return getList(
      '/api/v1/admin/operations/hostel/rooms$queryString',
      session: session,
    );
  }

  Future<Map<String, Object?>> createHostelRoom({
    required AuthSession session,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/hostel/rooms',
      payload,
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getHostelAllocations({
    required AuthSession session,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';

    return getList(
      '/api/v1/admin/operations/hostel/allocations$queryString',
      session: session,
    );
  }

  Future<Map<String, Object?>> allocateHostelBed({
    required AuthSession session,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/hostel/allocations',
      payload,
      session: session,
    );
  }

  Future<Map<String, Object?>> vacateHostelBed({
    required AuthSession session,
    required String allocationId,
  }) async {
    return putJson(
      '/api/v1/admin/operations/hostel/allocations/$allocationId/vacate',
      {},
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getVisitorGatePasses({
    required AuthSession session,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';

    return getList(
      '/api/v1/admin/operations/visitors/passes$queryString',
      session: session,
    );
  }

  Future<Map<String, Object?>> createVisitorGatePass({
    required AuthSession session,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/visitors/passes',
      payload,
      session: session,
    );
  }

  Future<Map<String, Object?>> checkoutVisitorGatePass({
    required AuthSession session,
    required String passId,
  }) async {
    return putJson(
      '/api/v1/admin/operations/visitors/passes/$passId/checkout',
      {},
      session: session,
    );
  }

  // --- 5. Student Health & Infirmary ---
  Future<Map<String, Object?>> getStudentHealthProfile({
    required AuthSession session,
    required String studentId,
  }) async {
    return getJson(
      '/api/v1/admin/operations/health/profiles/$studentId',
      session: session,
    );
  }

  Future<Map<String, Object?>> upsertStudentHealthProfile({
    required AuthSession session,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/health/profiles',
      payload,
      session: session,
    );
  }

  Future<List<Map<String, Object?>>> getInfirmaryVisits({
    required AuthSession session,
    String? studentId,
  }) async {
    final queryParams = <String, String>{};
    if (studentId != null && studentId.isNotEmpty) queryParams['studentId'] = studentId;

    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&')}';

    return getList(
      '/api/v1/admin/operations/health/infirmary-visits$queryString',
      session: session,
    );
  }

  Future<Map<String, Object?>> recordInfirmaryVisit({
    required AuthSession session,
    required Map<String, Object?> payload,
  }) async {
    return postJson(
      '/api/v1/admin/operations/health/infirmary-visits',
      payload,
      session: session,
    );
  }

  Map<String, String> _headers({String? bearerToken, AuthSession? devSession}) {
    return {
      'content-type': 'application/json',
      if (bearerToken != null) 'authorization': 'Bearer $bearerToken',
      if (devSession?.devNeonUserId != null) 'x-dev-neon-user-id': devSession!.devNeonUserId!,
      if (devSession?.devNeonUserId != null) 'x-dev-email': devSession!.email,
    };
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String? serverMessage;
    if (response.body.isNotEmpty) {
      try {
        final body = _decode(response);
        if (body['error'] is String && (body['error'] as String).trim().isNotEmpty) {
          serverMessage = (body['error'] as String).trim();
        } else if (body['message'] is String && (body['message'] as String).trim().isNotEmpty) {
          serverMessage = (body['message'] as String).trim();
        }
      } catch (_) {
        // Non-JSON response
      }
    }
    final errorMessage = serverMessage ??
        (response.statusCode >= 500
            ? 'Schoolic service is currently unavailable. Please try again later.'
            : 'Request failed (${response.statusCode})');
    throw ApiException(errorMessage, response.statusCode);
  }

  Map<String, Object?> _decode(http.Response response) {
    if (response.body.isEmpty) return const {};
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map) return parsed.cast<String, Object?>();
    } catch (_) {}
    return const {};
  }

  List<Object?> _decodeList(http.Response response) {
    if (response.body.isEmpty) return const [];
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is List) return parsed.cast<Object?>();
    } catch (_) {}
    return const [];
  }
}
