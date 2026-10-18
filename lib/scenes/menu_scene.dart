import 'dart:ui';

import 'package:flame/components.dart';

import '../engine/effects.dart';
import '../engine/palette.dart';
import '../engine/text.dart';
import '../engine/ui.dart';
import '../game/game_session.dart';
import '../models/player_stats.dart';
import '../services/api_client.dart';
import 'auth_scene.dart';
import 'bot_scene.dart';
import 'friend_scene.dart';
import 'leaderboard_scene.dart';
import 'scene.dart';
import 'settings_scene.dart';
import 'title_scene.dart';

class MenuScene extends Scene {
  int _selected = 0;
  PlayerStats? _stats;
  static bool _resumeChecked = false;

  @override
  void build() {
    add(SeaBackdrop(horizon: h - 70));
    final auth = game.auth;
    final items = <(String, VoidCallback)>[
      if (auth.isAuthenticated) ...[
        ('ОНЛАЙН-БІЙ', _online),
        ('З ДРУГОМ', () => game.show(() => FriendScene())),
        ('ПРОТИ БОТА', () => game.show(() => BotScene())),
        ('ЛІДЕРИ', () => game.show(() => LeaderboardScene())),
        ('НАЛАШТУВАННЯ', () => game.show(() => SettingsScene())),
        ('ВИЙТИ', _logout),
      ] else ...[
        ('ПРОТИ БОТА', () => game.show(() => BotScene())),
        ('УВІЙТИ', () => game.show(() => AuthScene(register: false))),
        ('НОВИЙ АКАУНТ', () => game.show(() => AuthScene(register: true))),
        ('ЛІДЕРИ', () => game.show(() => LeaderboardScene())),
        ('НАЛАШТУВАННЯ', () => game.show(() => SettingsScene())),
      ],
    ];
    var y = 92.0;
    for (var i = 0; i < items.length; i++) {
      final index = i;
      add(MenuItem(
        label: items[i].$1,
        onSelect: () {
          _selected = index;
          items[index].$2();
        },
        selected: () => _selected == index,
        onHover: () => _selected = index,
        position: Vector2(12, y),
        width: w - 24,
      ));
      y += 22;
    }
    if (auth.isAuthenticated) {
      _loadStats();
      _resume();
    }
  }

  Future<void> _loadStats() async {
    final auth = game.auth;
    try {
      final stats = await auth.guarded(() => auth.api.getPlayerStats(auth.nickname!));
      _stats = stats;
    } on ApiException {
      // статистика не обов'язкова
    }
  }

  // Після перезапуску застосунку - повертаємо в незавершену онлайн-гру.
  Future<void> _resume() async {
    if (_resumeChecked) return;
    _resumeChecked = true;
    final auth = game.auth;
    try {
      final current = await auth.guarded(() => auth.api.currentGame(auth.token!));
      if (current != null && isMounted) {
        await game.startGame(() async => OnlineGameSession(
              api: auth.api,
              token: auth.token!,
              mode: current.isPrivate ? GameMode.room : GameMode.random,
              initial: current,
            ));
      }
    } on ApiException {
      // нема - то й нема
    }
  }

  void _online() {
    final auth = game.auth;
    game.startGame(() async => OnlineGameSession(
          api: auth.api,
          token: auth.token!,
          mode: GameMode.random,
          initial: await auth.guarded(() => auth.api.findGame(auth.token!)),
        ));
  }

  void _logout() {
    game.confirm('ЗІЙТИ НА БЕРЕГ?', yes: 'ТАК', no: 'НІ', onYes: () async {
      await game.auth.logout();
      _resumeChecked = false;
      game.show(() => MenuScene());
    });
  }

  @override
  void onBack() => game.show(() => TitleScene());

  @override
  void render(Canvas canvas) {
    drawHeader(canvas, 'WHITE WAVES');
    // Табличка капітана
    canvas.pixelFrame(8, 26, w - 16, 56);
    final auth = game.auth;
    if (auth.isAuthenticated) {
      PixelText.draw(canvas, 'КАПІТАН', 16, 33);
      PixelText.draw(canvas, auth.nickname ?? '', 16, 45, size: 8);
      final s = _stats;
      PixelText.draw(canvas, 'ОЧКИ ${s?.points ?? '-'}', 16, 64);
      PixelText.draw(canvas, 'ПЕРЕМОГ ${s?.wins ?? '-'}', w - 16, 64, align: TAlign.right);
    } else {
      PixelText.draw(canvas, 'ГІСТЬ', 16, 33);
      PixelText.drawWrapped(canvas, 'УВІЙДИ, ЩОБ ГРАТИ ОНЛАЙН', 16, 49, w - 32);
    }
  }
}
