import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../models/lobby.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class GameSessionScreen extends StatefulWidget {
  final Lobby lobby;

  const GameSessionScreen({super.key, required this.lobby});

  @override
  State<GameSessionScreen> createState() => _GameSessionScreenState();
}

class _GameSessionScreenState extends State<GameSessionScreen> {
  late Lobby _lobby;
  WebSocketChannel? _channel;
  Timer? _pollTimer;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lobby = widget.lobby;
    _connectWebSocket();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  void _connectWebSocket() {
    final auth = context.read<AuthProvider>();
    try {
      final channel = WebSocketChannel.connect(Uri.parse('$wsBaseUrl/ws'));
      _channel = channel;
      channel.sink.add(jsonEncode({
        'type': 'subscribe',
        'token': auth.token,
        'lobbyId': _lobby.id,
      }));
      channel.stream.listen(
        (raw) => _handleWsMessage(raw),
        onError: (_) => _startPollingFallback(),
        onDone: () => _startPollingFallback(),
        cancelOnError: true,
      );
    } catch (_) {
      _startPollingFallback();
    }
  }

  // Будь-яка помилка тут (не рядок, не JSON, не той формат) просто
  // ігнорує конкретне повідомлення замість падіння всього стріму -
  // наступне коректне повідомлення (або polling-фолбек) все одно дійде.
  void _handleWsMessage(dynamic raw) {
    try {
      if (raw is! String) return;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return;
      if (data['type'] == 'state' && mounted) {
        final lobbyJson = data['lobby'];
        if (lobbyJson is Map<String, dynamic>) {
          setState(() => _lobby = Lobby.fromJson(lobbyJson));
        }
      }
    } catch (_) {
      // ігноруємо некоректне повідомлення
    }
  }

  void _startPollingFallback() {
    if (_pollTimer != null || !mounted) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollOnce());
    _pollOnce();
  }

  Future<void> _pollOnce() async {
    final auth = context.read<AuthProvider>();
    try {
      final lobby = await auth.guarded(() => auth.api.getLobby(auth.token!, _lobby.id));
      if (!mounted) return;
      setState(() => _lobby = lobby);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _markReady() async {
    final auth = context.read<AuthProvider>();
    setState(() => _ready = true);
    try {
      final lobby = await auth.guarded(() => auth.api.markReady(auth.token!, _lobby.id));
      if (!mounted) return;
      setState(() => _lobby = lobby);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _ready = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myNickname = context.read<AuthProvider>().nickname;
    final opponent = _lobby.nicknames.firstWhere((n) => n != myNickname, orElse: () => '?');
    return Scaffold(
      appBar: AppBar(title: const Text('Ігрова сесія')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              const Icon(Icons.sports_kabaddi, size: 48),
              const SizedBox(height: 16),
              Text('Суперник: $opponent', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Статус: ${_lobby.status}'),
              const SizedBox(height: 24),
              if (_lobby.inProgress) ...[
                const Text('Гру розпочато!', style: TextStyle(fontWeight: FontWeight.bold)),
              ] else ...[
                FilledButton(
                  onPressed: _ready ? null : _markReady,
                  child: Text(_ready ? 'Очікуємо суперника...' : 'Готовий'),
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Назад'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
