import 'dart:math' as math;
import 'dart:ui';


import '../engine/board.dart';
import '../engine/effects.dart';
import '../engine/palette.dart';
import '../engine/settings.dart';
import '../engine/sprites.dart';
import '../engine/text.dart';
import '../game/game_session.dart';
import '../game/game_view.dart';
import 'friend_scene.dart';
import 'scene.dart';

class ResultScene extends Scene {
  final GameView view;
  final BoardPainter _small = BoardPainter(BoardStyle.small);

  ResultScene(this.view);

  bool get _won => view.winner == 'you';
  bool get _cancelled => view.status == 'cancelled';

  @override
  void build() {
    if (_cancelled) {
      Sound.play(Sfx.error);
    } else if (_won) {
      add(Fireworks());
      Sound.play(Sfx.win);
      Haptics.heavy();
    } else {
      Sound.play(Sfx.lose);
      Haptics.heavy();
    }
    final mode = game.session?.mode;
    button('ЩЕ РАЗ', 12, h - 62, w - 24, () {
      if (mode == GameMode.room) {
        game.endSession();
        game.show(() => FriendScene());
      } else {
        game.replay();
      }
    }, primary: true);
    button('В МЕНЮ', 12, h - 32, w - 24, game.goMenu);
  }

  @override
  void render(Canvas canvas) {
    final title = _cancelled ? 'СКАСОВАНО' : (_won ? 'ПЕРЕМОГА!' : 'ПОРАЗКА');
    // Заголовок стрибає по пікселю
    final bounce = _won ? ((time * 4).floor().isEven ? 0.0 : -1.0) : 0.0;
    final ty = 34 + bounce;
    for (final (d, paper) in [(2.0, false), (1.0, true), (0.0, false)]) {
      PixelText.draw(canvas, title, w / 2 + d, ty + d, size: 16, align: TAlign.center, paper: paper);
    }
    const reasons = {
      'all_sunk': ['ВЕСЬ ВОРОЖИЙ ФЛОТ НА ДНІ', 'ТВІЙ ФЛОТ ЗНИЩЕНО'],
      'surrender': ['СУПЕРНИК ЗДАВСЯ', 'ТИ ЗДАВСЯ'],
      'timeout': ['СУПЕРНИК ПРОСПАВ БІЙ', 'ТИ ПРОПУСТИВ 3 ХОДИ'],
    };
    final reason = _cancelled ? 'ХТОСЬ ПОКИНУВ ГРУ' : (reasons[view.reason]?[_won ? 0 : 1] ?? '');
    PixelText.drawWrapped(canvas, reason, 8, 60, w - 16, align: TAlign.center);

    if (!_won && !_cancelled) _sinkingShip(canvas);
    if (_cancelled || view.opponent == null) return;

    // Обидва поля з розкритими кораблями
    final top = 96.0;
    final ext = BoardStyle.small.extent;
    final gap = math.max(4.0, (w - ext * 2) / 3);
    for (final (i, label, board) in [
      (0, view.opponent!.nickname, view.opponent!.board),
      (1, view.you.nickname, view.you.board),
    ]) {
      final x = (gap + i * (ext + gap)).floorToDouble();
      var name = label;
      final maxChars = (ext / 8).floor();
      if (name.length > maxChars) name = name.substring(0, maxChars);
      PixelText.draw(canvas, name, x + ext / 2, top, align: TAlign.center);
      canvas.save();
      canvas.translate(x, top + 12);
      _small.render(canvas, board, time: time);
      canvas.restore();
    }
    final y = top + 12 + ext + 10;
    final mySunk = view.opponent!.ships.length;
    final lost = view.you.ships.where((s) => s.sunk).length;
    PixelText.draw(canvas, 'ПОТОПЛЕНО: $mySunk/10', 12, y);
    PixelText.draw(canvas, 'ВТРАЧЕНО:  $lost/10', 12, y + 14);
    if (!view.local && _won) PixelText.draw(canvas, '+${100 + mySunk * 10} ОЧОК', 12, y + 28);
    if (!view.local && !_won) PixelText.draw(canvas, '+${mySunk * 10} ОЧОК', 12, y + 28);
  }

  // Корабель повільно йде під воду з бульбашками.
  void _sinkingShip(Canvas canvas) {
    final baseY = h - 100;
    final k = (time / 3).clamp(0.0, 1.0);
    final x = w - 56;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, baseY + 1));
    canvas.translate(x, baseY - 26 + k * 30);
    canvas.rotate(k * 0.35);
    canvas.scale(2);
    canvas.drawImage(Sprites.segment(Segment.boat, sunk: k > 0.5), Offset.zero, Palette.sprite);
    canvas.restore();
    canvas.px(x - 20, baseY, 70, 1);
    for (var i = 0; i < 3; i++) {
      final t = (time * 0.8 + i * 0.33) % 1;
      if (k > 0.3) canvas.pixelFrame(x + 10 + i * 6, baseY - t * 20, 3, 3);
    }
  }
}
