import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'game_session_screen.dart';

class FindGameScreen extends StatefulWidget {
  const FindGameScreen({super.key});

  @override
  State<FindGameScreen> createState() => _FindGameScreenState();
}

class _FindGameScreenState extends State<FindGameScreen> {
  Timer? _timer;
  String? _error;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_navigated) return;
    final auth = context.read<AuthProvider>();
    try {
      final result = await auth.guarded(() => auth.api.findGame(auth.token!));
      if (!mounted) return;
      if (result.matchFound) {
        _navigated = true;
        _timer?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => GameSessionScreen(lobby: result.lobby)),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _timer?.cancel();
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пошук гри')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ] else ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Очікування суперника...'),
              ],
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Назад'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
