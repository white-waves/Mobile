import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../game/game_view.dart';
import '../game/rules.dart';
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

const _messages = {
  'Invalid credentials': 'Невірний логін або пароль',
  'Login already exists.': 'Такий логін уже зайнятий',
  'Nickname already exists.': 'Такий нікнейм уже зайнятий',
  'Login or nickname already exists.': 'Логін або нікнейм уже зайнятий',
  'Password must be at least 6 characters.': 'Пароль має містити щонайменше 6 символів',
  'Nickname must be 3-16 characters: latin letters, digits, _ or -.': 'Нікнейм: 3-16 символів, латиниця, цифри, _ або -',
  'Login must be at most 64 characters.': 'Логін задовгий',
  'Old password incorrect': 'Старий пароль невірний',
  'Invalid token': 'Сесія завершилась, увійди знову',
  'Not your turn': 'Зараз не твій хід',
  'Cell was already shot.': 'Сюди вже стріляли',
  'Room not found': 'Кімнату не знайдено',
  'You are already in a game': 'Ти вже в грі',
  'Battle is not in progress': 'Бій не триває',
  'Player not found': 'Гравця не знайдено',
  'Lobby not found': 'Гру не знайдено',
};

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
      throw ApiException(response.statusCode, err is String ? (_messages[err] ?? err) : 'Помилка сервера');
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

  Map<String, String> _auth(String token, {bool json = false}) => {
        'Authorization': 'Bearer $token',
        if (json) 'Content-Type': 'application/json',
      };

  GameView _gameFrom(http.Response response) {
    final data = _ensureOk(response);
    try {
      return GameView.fromJson(data['game'] as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(response.statusCode, 'Некоректна відповідь сервера.');
    }
  }

  Future<GameView> findGame(String token) => _guard(() async =>
      _gameFrom(await _client.post(_uri('/api/find-game'), headers: _auth(token))));

  Future<GameView> createRoom(String token) => _guard(() async =>
      _gameFrom(await _client.post(_uri('/api/rooms'), headers: _auth(token))));

  Future<GameView> joinRoom(String token, String code) => _guard(() async => _gameFrom(await _client.post(
        _uri('/api/rooms/join'),
        headers: _auth(token, json: true),
        body: jsonEncode({'code': code}),
      )));

  Future<GameView?> currentGame(String token) => _guard(() async {
        final response = await _client.get(_uri('/api/current-game'), headers: _auth(token));
        final data = _ensureOk(response);
        final game = data['game'];
        return game is Map<String, dynamic> ? GameView.fromJson(game) : null;
      });

  Future<GameView> getGame(String token, String id) => _guard(() async =>
      _gameFrom(await _client.get(_uri('/api/lobby/$id'), headers: _auth(token))));

  // ships == null - сервер розставить кораблі випадково.
  Future<GameView> ready(String token, String id, List<Ship>? ships) => _guard(() async => _gameFrom(await _client.post(
        _uri('/api/lobby/$id/ready'),
        headers: _auth(token, json: true),
        body: jsonEncode(ships == null ? {} : {'ships': ships.map((s) => s.toJson()).toList()}),
      )));

  Future<GameView> shoot(String token, String id, int x, int y) => _guard(() async => _gameFrom(await _client.post(
        _uri('/api/lobby/$id/shoot'),
        headers: _auth(token, json: true),
        body: jsonEncode({'x': x, 'y': y}),
      )));

  Future<GameView> leave(String token, String id) => _guard(() async =>
      _gameFrom(await _client.post(_uri('/api/lobby/$id/leave'), headers: _auth(token))));

  Future<List<LeaderboardEntry>> leaderboard({int limit = 50}) => _guard(() async {
        final response = await _client.get(_uri('/api/leaderboard?limit=$limit'));
        final data = _ensureOk(response);
        try {
          return (data['players'] as List)
              .map((p) => LeaderboardEntry.fromJson(p as Map<String, dynamic>))
              .toList();
        } catch (_) {
          throw ApiException(response.statusCode, 'Некоректна відповідь сервера.');
        }
      });
}
