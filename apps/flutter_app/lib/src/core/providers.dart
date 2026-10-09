import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController(ref.watch(apiClientProvider))..restore();
});

class AuthController extends ChangeNotifier {
  AuthController(this._apiClient);

  static const _storageKey = 'schoolic.auth.session';

  final ApiClient _apiClient;
  AuthSession? session;
  bool isLoading = true;
  String? error;

  Future<void> restore() async {
    isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final cached = AuthSession.fromJson(jsonDecode(raw) as Map<String, Object?>);
      session = await _apiClient.currentUser(
        bearerToken: cached.bearerToken,
        devSession: cached.devNeonUserId == null ? null : cached,
      );
      await _persist();
    } catch (_) {
      session = null;
      await prefs.remove(_storageKey);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      session = await _apiClient.signInWithNeon(email: email, password: password);
      await _persist();
    } on ApiException catch (exception) {
      error = exception.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> devSignIn(AppRole role) async {
    final devSession = AuthSession(
      email: role == AppRole.admin ? 'admin@schoolic.local' : 'teacher@schoolic.local',
      roles: [role],
      schoolId: 'dev-school',
      devNeonUserId: role == AppRole.admin ? 'dev-admin' : 'dev-teacher',
    );

    isLoading = true;
    error = null;
    notifyListeners();
    try {
      session = await _apiClient.currentUser(devSession: devSession);
    } on ApiException {
      session = devSession;
    } finally {
      await _persist();
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    session = null;
    notifyListeners();
  }

  Future<void> _persist() async {
    final value = session;
    if (value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(value.toJson()));
  }
}
