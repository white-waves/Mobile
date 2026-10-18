import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../services/api_client.dart';
import 'game_view.dart';
import 'rules.dart';

enum GameMode { random, room, bot }

enum BotLevel { easy, hard }

// Спільний інтерфейс онлайн-гри та гри з ботом.
abstract class GameSession extends ChangeNotifier {
  GameMode get mode;
  GameView get view;
  Future<void> place(List<Ship>? ships);
  Future<void> shoot(int x, int y);
  Future<void> leave();
}

// ---------------------------------------------------------------------------
// Онлайн: стан приходить по WebSocket, без нього - опитуємо сервер.

class OnlineGameSession extends GameSession {
  final ApiClient api;
  final String token;
  @override
  final GameMode mode;
  GameView _view;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  Timer? _poller;
  Timer? _reconnect;
  bool _wsOpen = false;
  bool _disposed = false;

  OnlineGameSession({required this.api, required this.token, required this.mode, required GameView initial})
      : _view = initial {
    _connect();
    _poller = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  GameView get view => _view;

  void _set(GameView view) {
    if (_disposed) return;
    _view = view;
    notifyListeners();
  }

  void _connect() {
    if (_disposed || !_view.active) return;
    try {
      final channel = WebSocketChannel.connect(Uri.parse('$wsBaseUrl/ws'));
      _channel = channel;
      channel.sink.add(jsonEncode({'type': 'subscribe', 'token': token, 'lobbyId': _view.id}));
      _wsSub = channel.stream.listen(
        (raw) {
          _wsOpen = true;
          try {
            final data = jsonDecode(raw as String);
            if (data is Map<String, dynamic> && data['type'] == 'state' && data['game'] is Map<String, dynamic>) {
              _set(GameView.fromJson(data['game'] as Map<String, dynamic>));
            }
          } catch (_) {
            // ігноруємо некоректне повідомлення
          }
        },
        onError: (_) => _onWsClosed(),
        onDone: _onWsClosed,
        cancelOnError: true,
      );
    } catch (_) {
      _onWsClosed();
    }
  }

  void _onWsClosed() {
    _wsOpen = false;
    if (_disposed || !_view.active) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 3), _connect);
  }

  Future<void> _poll() async {
    if (_disposed || !_view.active) return;
    try {
      // У публічній черзі find-game ще й підтверджує, що ми досі чекаємо.
      if (_view.status == 'waiting' && !_view.isPrivate) {
        _set(await api.findGame(token));
      } else if (!_wsOpen) {
        _set(await api.getGame(token, _view.id));
      }
    } on ApiException {
      // наступне опитування спробує ще раз
    }
  }

  @override
  Future<void> place(List<Ship>? ships) async => _set(await api.ready(token, _view.id, ships));

  @override
  Future<void> shoot(int x, int y) async => _set(await api.shoot(token, _view.id, x, y));

  @override
  Future<void> leave() async => _set(await api.leave(token, _view.id));

  @override
  void dispose() {
    _disposed = true;
    _poller?.cancel();
    _reconnect?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Офлайн-гра проти бота.

class LocalGameSession extends GameSession {
  final String nickname;
  final BotLevel level;
  final Random _rnd = Random();
  String _status = 'placing';
  List<Ship> _myShips = [];
  String _myGrid = emptyGrid;
  final List<Ship> _botShips = randomFleet();
  String _botGrid = emptyGrid;
  bool _myTurn = true;
  LastShot? _lastShot;
  String? _winner;
  String? _reason;
  Timer? _timer;
  bool _disposed = false;

  LocalGameSession({required this.nickname, required this.level});

  @override
  GameMode get mode => GameMode.bot;

  @override
  GameView get view {
    final finished = _status == 'finished';
    return GameView(
      id: 'local',
      local: true,
      status: _status,
      isPrivate: false,
      code: null,
      you: PlayerSide(
        nickname: nickname,
        ready: _status != 'placing',
        board: ownBoard(_myShips, _myGrid),
        ships: [
          for (final s in _myShips)
            Ship(x: s.x, y: s.y, length: s.length, vertical: s.vertical, sunk: isSunk(s, _myGrid)),
        ],
      ),
      opponent: PlayerSide(
        nickname: level == BotLevel.easy ? 'БОТ-ЮНГА' : 'БОТ-АДМІРАЛ',
        ready: true,
        board: finished ? ownBoard(_botShips, _botGrid) : _botGrid,
        ships: _botShips.where((s) => isSunk(s, _botGrid)).toList(),
      ),
      yourTurn: _status == 'playing' && _myTurn,
      timeLeftMs: null,
      lastShot: _lastShot,
      winner: _winner,
      reason: _reason,
    );
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> place(List<Ship>? ships) async {
    _myShips = ships ?? randomFleet();
    _status = 'playing';
    _myTurn = _rnd.nextBool();
    _emit();
    if (!_myTurn) _scheduleBot();
  }

  @override
  Future<void> shoot(int x, int y) async {
    if (_status != 'playing' || !_myTurn) throw ApiException(0, 'Зараз не твій хід');
    final shot = applyShot(_botShips, _botGrid, x, y);
    if (shot == null) throw ApiException(0, 'Сюди вже стріляли');
    _botGrid = shot.grid;
    _lastShot = LastShot(byMe: true, x: x, y: y, result: shot.result);
    if (allSunk(_botShips, _botGrid)) {
      _finish('you', 'all_sunk');
    } else if (shot.result == 'miss') {
      _myTurn = false;
      _scheduleBot();
    }
    _emit();
  }

  void _scheduleBot() {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: 650 + _rnd.nextInt(500)), _botMove);
  }

  void _botMove() {
    if (_status != 'playing' || _disposed) return;
    final (x, y) = level == BotLevel.easy ? _easyShot(_myGrid) : _smartShot(_myGrid);
    final shot = applyShot(_myShips, _myGrid, x, y)!;
    _myGrid = shot.grid;
    _lastShot = LastShot(byMe: false, x: x, y: y, result: shot.result);
    if (allSunk(_myShips, _myGrid)) {
      _finish('opponent', 'all_sunk');
    } else if (shot.result == 'miss') {
      _myTurn = true;
    } else {
      _scheduleBot();
    }
    _emit();
  }

  void _finish(String winner, String reason) {
    _status = 'finished';
    _winner = winner;
    _reason = reason;
    _timer?.cancel();
  }

  @override
  Future<void> leave() async {
    if (_status == 'playing') {
      _finish('opponent', 'surrender');
    } else {
      _status = 'cancelled';
    }
    _emit();
  }

  // Довжини кораблів, що ще на плаву, за тим, що видно на сітці.
  List<int> _remaining(String grid) {
    final left = [...fleet];
    final seen = <int>{};
    for (var i = 0; i < 100; i++) {
      if (grid[i] != '#' || seen.contains(i)) continue;
      final x = i % 10;
      final horizontal = x < 9 && grid[i + 1] == '#';
      var cx = x;
      var cy = i ~/ 10;
      var length = 0;
      while (inBounds(cx, cy) && grid[cy * 10 + cx] == '#') {
        seen.add(cy * 10 + cx);
        length++;
        if (horizontal) {
          cx++;
        } else {
          cy++;
        }
      }
      left.remove(length);
    }
    return left;
  }

  // Карта щільності: скільки можливих положень кораблів накривають клітинку.
  (int, int) _smartShot(String grid) {
    final weights = List<int>.filled(100, 0);
    for (final length in _remaining(grid)) {
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 10; x++) {
          for (final vertical in [false, true]) {
            final cells = Ship(x: x, y: y, length: length, vertical: vertical).cells;
            if (!cells.every((c) => inBounds(c.$1, c.$2))) continue;
            final marks = cells.map((c) => grid[c.$2 * 10 + c.$1]).toList();
            if (marks.any((m) => m == 'o' || m == '#')) continue;
            final hits = marks.where((m) => m == 'X').length;
            final weight = hits > 0 ? 1 + hits * 50 : 1;
            for (final c in cells) {
              weights[c.$2 * 10 + c.$1] += weight;
            }
          }
        }
      }
    }
    var best = -1;
    var options = <int>[];
    for (var i = 0; i < 100; i++) {
      if (grid[i] != '.') continue;
      if (weights[i] > best) {
        best = weights[i];
        options = [i];
      } else if (weights[i] == best) {
        options.add(i);
      }
    }
    final i = options[_rnd.nextInt(options.length)];
    return (i % 10, i ~/ 10);
  }

  // Легкий бот: навмання, але добиває сусідні з влучанням клітинки.
  (int, int) _easyShot(String grid) {
    final targets = <int>[];
    for (var i = 0; i < 100; i++) {
      if (grid[i] != 'X') continue;
      final x = i % 10;
      final y = i ~/ 10;
      for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        if (inBounds(x + dx, y + dy) && grid[(y + dy) * 10 + x + dx] == '.') targets.add((y + dy) * 10 + x + dx);
      }
    }
    if (targets.isEmpty) {
      for (var i = 0; i < 100; i++) {
        if (grid[i] == '.') targets.add(i);
      }
    }
    final i = targets[_rnd.nextInt(targets.length)];
    return (i % 10, i ~/ 10);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

@visibleForTesting
List<Ship> debugBotShips(LocalGameSession s) => s._botShips;
