import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../services/auth_storage.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final AuthStorage _storage = AuthStorage();

  AuthStatus status = AuthStatus.unknown;
  String? token;
  String? userLogin;
  String? nickname;

  ApiClient get api => _api;

  Future<void> loadSession() async {
    final session = await _storage.load();
    if (session == null) {
      status = AuthStatus.unauthenticated;
    } else {
      token = session.token;
      userLogin = session.login;
      nickname = session.nickname;
      status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  Future<void> register({
    required String login,
    required String password,
    required String nickname,
  }) async {
    await _api.register(login: login, password: password, nickname: nickname);
    final result = await _api.login(login: login, password: password);
    await _applyAuthResult(result);
  }

  Future<void> login({required String login, required String password}) async {
    final result = await _api.login(login: login, password: password);
    await _applyAuthResult(result);
  }

  Future<void> _applyAuthResult(AuthResult result) async {
    token = result.token;
    userLogin = result.login;
    nickname = result.nickname;
    await _storage.save(token: result.token, login: result.login, nickname: result.nickname);
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    await _api.changePassword(token: token!, oldPassword: oldPassword, newPassword: newPassword);
  }

  Future<void> logout() async {
    await _storage.clear();
    token = null;
    userLogin = null;
    nickname = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<T> guarded<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await logout();
      }
      rethrow;
    }
  }
}
