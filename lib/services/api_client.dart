import 'dart:convert';

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

  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Map<String, dynamic> _ensureOk(http.Response response) {
    final data = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, (data['error'] as String?) ?? 'Помилка сервера');
    }
    return data;
  }

  Future<void> register({
    required String login,
    required String password,
    required String nickname,
  }) async {
    final response = await _client.post(
      _uri('/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login': login, 'password': password, 'nickname': nickname}),
    );
    _ensureOk(response);
  }

  Future<AuthResult> login({required String login, required String password}) async {
    final response = await _client.post(
      _uri('/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login': login, 'password': password}),
    );
    final data = _ensureOk(response);
    final user = data['user'] as Map<String, dynamic>;
    return AuthResult(
      token: data['token'] as String,
      login: user['login'] as String,
      nickname: user['nickname'] as String,
    );
  }

  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await _client.post(
      _uri('/api/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'oldPassword': oldPassword, 'newPassword': newPassword}),
    );
    _ensureOk(response);
  }

  Future<PlayerStats> getPlayerStats(String nickname) async {
    final response = await _client.get(_uri('/api/player-stats/$nickname'));
    final data = _ensureOk(response);
    return PlayerStats.fromJson(data);
  }

  Future<FindGameResult> findGame(String token) async {
    final response = await _client.post(
      _uri('/api/find-game'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _ensureOk(response);
    return FindGameResult.fromJson(data);
  }

  Future<Lobby> getLobby(String token, String lobbyId) async {
    final response = await _client.get(
      _uri('/api/lobby/$lobbyId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _ensureOk(response);
    return Lobby.fromJson(data['lobby'] as Map<String, dynamic>);
  }

  Future<Lobby> markReady(String token, String lobbyId) async {
    final response = await _client.post(
      _uri('/api/lobby/$lobbyId/ready'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _ensureOk(response);
    return Lobby.fromJson(data['lobby'] as Map<String, dynamic>);
  }
}
