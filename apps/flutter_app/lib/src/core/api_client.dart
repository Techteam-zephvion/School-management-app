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
