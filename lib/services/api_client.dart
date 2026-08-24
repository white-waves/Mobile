import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/lobby.dart';
import '../models/player_stats.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class AuthResult {
  final String token;
  final String login;
  final String nickname;

  AuthResult({required this.token, required this.login, required this.nickname});
}

class ApiClient {
  final http.Client _client = http.Client();
  static const _timeout = Duration(seconds: 10);

  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

  // Усі публічні методи йдуть через _guard, тож викликачам ніколи не
  // прилітає нічого, крім ApiException - незалежно від того, чи впала
  // мережа, чи сервер повернув не-JSON, чи відповідь має неочікувану форму.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body().timeout(_timeout);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(0, "Сервер не відповідає. Перевір з'єднання.");
    } on SocketException {
      throw ApiException(0, "Немає з'єднання із сервером.");
    } on http.ClientException {
      throw ApiException(0, "Немає з'єднання із сервером.");
    } on FormatException {
      throw ApiException(0, 'Некоректна відповідь сервера.');
    } catch (e) {
      throw ApiException(0, 'Сталася непередбачена помилка.');
    }
  }

  Map<String, dynamic> _ensureOk(http.Response response) {
    Map<String, dynamic> data;
    try {
      final body = response.body.isEmpty ? '{}' : response.body;
      final decoded = jsonDecode(body);
      data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      throw ApiException(response.statusCode, 'Некоректна відповідь сервера.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final err = data['error'];
      throw ApiException(response.statusCode, err is String ? err : 'Помилка сервера');
    }
    return data;
  }

  Future<void> register({
    required String login,
    required String password,
    required String nickname,
  }) {
    return _guard(() async {
      final response = await _client.post(
        _uri('/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'login': login, 'password': password, 'nickname': nickname}),
      );
      _ensureOk(response);
    });
  }

  Future<AuthResult> login({required String login, required String password}) {
    return _guard(() async {
      final response = await _client.post(
        _uri('/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'login': login, 'password': password}),
      );
      final data = _ensureOk(response);
      final user = data['user'];
      final token = data['token'];
      if (user is! Map<String, dynamic> ||
          token is! String ||
          user['login'] is! String ||
          user['nickname'] is! String) {
        throw ApiException(response.statusCode, 'Некоректна відповідь сервера.');
      }
      return AuthResult(
        token: token,
        login: user['login'] as String,
        nickname: user['nickname'] as String,
      );
    });
  }

  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) {
    return _guard(() async {
      final response = await _client.post(
        _uri('/api/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'oldPassword': oldPassword, 'newPassword': newPassword}),
      );
      _ensureOk(response);
    });
  }

  Future<PlayerStats> getPlayerStats(String nickname) {
    return _guard(() async {
      final response = await _client.get(_uri('/api/player-stats/$nickname'));
      final data = _ensureOk(response);
      try {
        return PlayerStats.fromJson(data);
      } catch (_) {
        throw ApiException(response.statusCode, 'Некоректна відповідь сервера.');
      }
    });
  }

  Future<FindGameResult> findGame(String token) {
    return _guard(() async {
      final response = await _client.post(
        _uri('/api/find-game'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = _ensureOk(response);
      try {
        return FindGameResult.fromJson(data);
      } catch (_) {
        throw ApiException(response.statusCode, 'Некоректна відповідь сервера.');
      }
    });
  }

  Future<Lobby> getLobby(String token, String lobbyId) {
    return _guard(() async {
      final response = await _client.get(
        _uri('/api/lobby/$lobbyId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = _ensureOk(response);
      try {
        return Lobby.fromJson(data['lobby'] as Map<String, dynamic>);
      } catch (_) {
        throw ApiException(response.statusCode, 'Некоректна відповідь сервера.');
      }
    });
  }

  Future<Lobby> markReady(String token, String lobbyId) {
    return _guard(() async {
      final response = await _client.post(
        _uri('/api/lobby/$lobbyId/ready'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = _ensureOk(response);
      try {
        return Lobby.fromJson(data['lobby'] as Map<String, dynamic>);
      } catch (_) {
        throw ApiException(response.statusCode, 'Некоректна відповідь сервера.');
      }
    });
  }
}
