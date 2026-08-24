import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_stats.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'change_password_screen.dart';
import 'find_game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<PlayerStats>? _statsFuture;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    final auth = context.read<AuthProvider>();
    setState(() {
      _statsFuture = auth.guarded(() => auth.api.getPlayerStats(auth.nickname!));
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(auth.nickname ?? 'White Waves'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadStats(),
        child: FutureBuilder<PlayerStats>(
          future: _statsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final message =
                  snapshot.error is ApiException ? (snapshot.error as ApiException).message : 'Помилка завантаження';
              return ListView(
                children: [
                  const SizedBox(height: 40),
                  Center(child: Text(message)),
                ],
              );
            }
            final stats = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Країна: ${stats.country}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                _StatTile(label: 'Бої', value: stats.battles),
                _StatTile(label: 'Перемоги', value: stats.wins),
                _StatTile(label: 'Знищено кораблів', value: stats.shipsDestroyed),
                _StatTile(label: 'Очки', value: stats.points),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FindGameScreen()),
                  ),
                  child: const Text('Знайти гру'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                  ),
                  child: const Text('Змінити пароль'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
