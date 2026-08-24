import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredSession {
  final String token;
  final String login;
  final String nickname;

  StoredSession({required this.token, required this.login, required this.nickname});
}

class AuthStorage {
  static const _tokenKey = 'token';
  static const _loginKey = 'login';
  static const _nicknameKey = 'nickname';

  final _storage = const FlutterSecureStorage();

  Future<void> save({required String token, required String login, required String nickname}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _loginKey, value: login);
    await _storage.write(key: _nicknameKey, value: nickname);
  }

  Future<StoredSession?> load() async {
    final token = await _storage.read(key: _tokenKey);
    final login = await _storage.read(key: _loginKey);
    final nickname = await _storage.read(key: _nicknameKey);
    if (token == null || login == null || nickname == null) {
      return null;
    }
    return StoredSession(token: token, login: login, nickname: nickname);
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
