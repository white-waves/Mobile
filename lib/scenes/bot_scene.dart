import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../engine/palette.dart';
import '../engine/settings.dart';
import '../engine/text.dart';
import '../game/game_session.dart';
import '../white_waves_game.dart';
import 'scene.dart';

// Вибір суперника-бота: дві картки з портретами.
class BotScene extends Scene {
  @override
  void build() {
    backButton();
    final cardH = ((h - 60) / 2).clamp(90, 112).toDouble();
    add(_BotCard(
      level: BotLevel.easy,
      title: 'ЮНГА',
      text: 'СТРІЛЯЄ НАВМАННЯ. ДЛЯ РОЗМИНКИ.',
      position: Vector2(12, 28),
      size: Vector2(w - 24, cardH),
    ));
    add(_BotCard(
      level: BotLevel.hard,
      title: 'АДМІРАЛ',
      text: 'РАХУЄ ІМОВІРНОСТІ. ПОЩАДИ НЕ БУДЕ.',
      position: Vector2(12, 40 + cardH),
      size: Vector2(w - 24, cardH),
    ));
  }

  @override
  void render(Canvas canvas) => drawHeader(canvas, 'ПРОТИ БОТА');
}

class _BotCard extends PositionComponent with TapCallbacks, HasGameReference<WhiteWavesGame> {
  final BotLevel level;
  final String title;
  final String text;
  bool _down = false;
  double _t = 0;

  _BotCard({required this.level, required this.title, required this.text, required super.position, required super.size});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final inv = _down;
    if (inv) canvas.px(0, 0, size.x, size.y);
    canvas.pixelFrame(0, 0, size.x, size.y, paper: inv);
    canvas.pixelFrame(2, 2, size.x - 4, size.y - 4, paper: inv);
    _portrait(canvas, 12, 14, inv);
    PixelText.draw(canvas, title, 64, 16, size: 16, paper: inv);
    PixelText.drawWrapped(canvas, text, 64, 40, size.x - 72, paper: inv, lineHeight: 11);
    // "Зірки" складності
    final stars = level == BotLevel.easy ? 1 : 3;
    for (var i = 0; i < 3; i++) {
      final x = 64.0 + i * 12;
      final y = size.y - 18;
      if (i < stars) {
        canvas.px(x + 3, y, 2, 8, inv);
        canvas.px(x, y + 3, 8, 2, inv);
        canvas.px(x + 2, y + 2, 4, 4, inv);
      } else {
        canvas.px(x + 3, y + 3, 2, 2, inv);
      }
    }
  }

  // Піксельний портрет 40x48: юнга в безкозирці або адмірал у кашкеті.
  void _portrait(Canvas c, double x, double y, bool paper) {
    void p(double dx, double dy, [double w = 1, double h = 1]) => c.px(x + dx, y + dy, w, h, paper);
    final blink = (_t * 0.7 % 4) < 0.15;
    // голова
    p(10, 14, 20, 1);
    p(8, 15, 1, 18);
    p(31, 15, 1, 18);
    p(10, 33, 20, 1);
    p(9, 33, 1, 1);
    p(30, 33, 1, 1);
    // очі
    if (blink) {
      p(13, 22, 4, 1);
      p(23, 22, 4, 1);
    } else {
      p(14, 20, 2, 3);
      p(24, 20, 2, 3);
    }
    // ніс і рот
    p(19, 24, 2, 3);
    if (level == BotLevel.easy) {
      p(15, 29, 10, 1);
      p(14, 28, 1, 1);
      p(25, 28, 1, 1);
      // безкозирка
      p(8, 8, 24, 6);
      p(10, 6, 20, 2);
      p(32, 10, 4, 2);
      p(35, 12, 2, 6);
    } else {
      p(15, 29, 10, 2);
      // вуса
      p(12, 27, 6, 1);
      p(22, 27, 6, 1);
      // кашкет з кокардою
      p(4, 11, 32, 3);
      p(6, 4, 28, 7);
      p(18, 6, 4, 3);
      c.px(x + 19, y + 7, 2, 1, !paper);
      // погони
      p(0, 38, 10, 3);
      p(30, 38, 10, 3);
      for (var i = 0; i < 3; i++) {
        p(1 + i * 3.0, 42, 1, 3);
        p(31 + i * 3.0, 42, 1, 3);
      }
    }
    // плечі
    p(4, 36, 32, 1);
    p(2, 37, 1, 10);
    p(37, 37, 1, 10);
    if (level == BotLevel.easy) {
      // смугаста тільняшка
      for (var i = 0; i < 4; i++) {
        p(3, 39 + i * 2.0, 34, 1);
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) => _down = true;

  @override
  void onTapCancel(TapCancelEvent event) => _down = false;

  @override
  void onTapUp(TapUpEvent event) {
    _down = false;
    Sound.play(Sfx.click);
    Haptics.light();
    final nickname = game.auth.nickname ?? 'ГРАВЕЦЬ';
    game.startGame(() async => LocalGameSession(nickname: nickname, level: level));
  }
}
