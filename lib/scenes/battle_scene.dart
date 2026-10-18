import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../engine/board.dart';
import '../engine/effects.dart';
import '../engine/palette.dart';
import '../engine/settings.dart';
import '../engine/sprites.dart';
import '../engine/text.dart';
import '../game/game_view.dart';
import '../game/rules.dart';
import '../services/api_client.dart';
import 'result_scene.dart';
import 'scene.dart';

// Бій. Нові стани гри стають у чергу: кожен постріл спершу летить
// снарядом, і лише після "падіння" поле оновлюється з вибухом або бризками.
class BattleScene extends Scene with TapCallbacks {
  final BoardPainter _big = BoardPainter(BoardStyle.big);
  late final BoardPainter _small;
  late Vector2 _enemyPos;
  late Vector2 _minePos;

  late GameView _shown;
  final List<GameView> _queue = [];
  bool _animating = false;
  bool _shooting = false;
  bool _finishing = false;
  (int, int)? _aim;
  final List<(bool, String, String)> _log = []; // (мій постріл, клітинка, результат)

  @override
  void build() {
    final session = game.session!;
    _shown = session.view;
    session.addListener(_onSession);
    _enemyPos = Vector2(((w - BoardStyle.big.extent) / 2).floorToDouble(), 40);
    final mineTop = _enemyPos.y + BoardStyle.big.extent + 22;
    // Своє поле більше, якщо екран дозволяє.
    final fits = h - mineTop - 30 >= BoardStyle.medium.extent && w - BoardStyle.medium.extent - 14 >= 72;
    _small = BoardPainter(fits ? BoardStyle.medium : BoardStyle.small);
    _minePos = Vector2(6, mineTop);
    add(_FlagButton(position: Vector2(w - 70, h - 26), onTap: onBack));
    add(Banner('БІЙ!', y: 120));
    Sound.play(Sfx.match);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (isMounted && _shown.yourTurn) _yourTurnBanner();
    });
  }

  @override
  void onRemove() {
    game.session?.removeListener(_onSession);
    super.onRemove();
  }

  void _onSession() {
    final s = game.session;
    if (s == null) return;
    _queue.add(s.view);
    _pump();
  }

  // Обробляє наступний стан із черги.
  void _pump() {
    if (_animating || _queue.isEmpty || !isMounted) return;
    final next = _queue.removeAt(0);
    final prev = _shown;
    final shot = next.lastShot;
    if (shot != null && !shot.sameAs(prev.lastShot)) {
      _animating = true;
      _animateShot(shot, onImpact: () {
        _shown = next;
        _impact(shot, next);
        _afterUpdate(prev, next);
        Future.delayed(Duration(milliseconds: shot.result == 'miss' ? 250 : 450), () {
          _animating = false;
          _pump();
        });
      });
    } else {
      _shown = next;
      _afterUpdate(prev, next);
      _pump();
    }
  }

  void _afterUpdate(GameView prev, GameView next) {
    if (next.yourTurn && !prev.yourTurn && next.status == 'playing') {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (isMounted && _shown.yourTurn) _yourTurnBanner();
      });
    }
    if (prev.yourTurn && !next.yourTurn && next.status == 'playing' && next.lastShot == null) {
      game.toast('ХІД ПРОПУЩЕНО');
    }
    if (next.status != 'playing' && !_finishing) {
      _finishing = true;
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (isMounted) game.show(() => ResultScene(_shown));
      });
    }
  }

  void _yourTurnBanner() {
    add(Banner('ТВІЙ ХІД', y: 110));
    Sound.play(Sfx.turn);
    Haptics.light();
  }

  Vector2 _enemyCellCenter(int x, int y) =>
      _enemyPos + Vector2(_big.cellLeft(x) + 8, _big.cellTop(y) + 8);

  Vector2 _myCellCenter(int x, int y) => _minePos + Vector2(_small.cellLeft(x) + _small.style.cell / 2, _small.cellTop(y) + _small.style.cell / 2);

  void _animateShot(LastShot shot, {required VoidCallback onImpact}) {
    final to = shot.byMe ? _enemyCellCenter(shot.x, shot.y) : _myCellCenter(shot.x, shot.y);
    final from = shot.byMe ? Vector2(to.x, -8) : Vector2(w + 8, to.y - 90);
    Sound.play(Sfx.fire, volume: 0.5);
    add(Shell(from: from, to: to, onImpact: onImpact, duration: shot.byMe ? 0.4 : 0.55));
  }

  void _impact(LastShot shot, GameView v) {
    final at = shot.byMe ? _enemyCellCenter(shot.x, shot.y) : _myCellCenter(shot.x, shot.y);
    final scale = shot.byMe ? 1.0 : 0.6;
    final cell = cellName(shot.x, shot.y);
    switch (shot.result) {
      case 'miss':
        add(Splash(position: at));
        Sound.play(Sfx.splash);
        _log.insert(0, (shot.byMe, cell, 'miss'));
      case 'hit':
        add(Explosion(position: at, radius: 12 * scale));
        Sound.play(Sfx.boom);
        game.shake(shot.byMe ? 0.2 : 0.35);
        shot.byMe ? Haptics.medium() : Haptics.heavy();
        if (shot.byMe) add(FloatingText('ВЛУЧАННЯ!', position: at - Vector2(0, 14)));
        _log.insert(0, (shot.byMe, cell, 'hit'));
      case 'sunk':
        add(Explosion(position: at, radius: 22 * scale));
        add(Explosion(position: at + Vector2(6, -4), radius: 12 * scale));
        Sound.play(Sfx.sunk);
        game.shake(0.5);
        Haptics.heavy();
        add(FloatingText(shot.byMe ? 'ПОТОПЛЕНО!' : 'ВТРАТА!', position: at - Vector2(0, 16)));
        _log.insert(0, (shot.byMe, cell, 'sunk'));
    }
    if (_log.length > 8) _log.removeLast();
  }

  // ---- введення ---------------------------------------------------------

  (int, int)? _enemyCellAt(Vector2 p) => _big.cellAt(p.x - _enemyPos.x, p.y - _enemyPos.y);

  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void onTapDown(TapDownEvent event) {
    final cell = _enemyCellAt(event.localPosition);
    if (cell != null && _shown.yourTurn && !_animating && !_shooting) _aim = cell;
  }

  @override
  void onTapCancel(TapCancelEvent event) => _aim = null;

  @override
  void onTapUp(TapUpEvent event) {
    final cell = _enemyCellAt(event.localPosition);
    _aim = null;
    if (cell == null) return;
    if (!_shown.yourTurn || _shown.status != 'playing') {
      Sound.play(Sfx.error, volume: 0.4);
      add(FloatingText('ЗАЧЕКАЙ', position: _enemyCellCenter(cell.$1, cell.$2)));
      return;
    }
    if (_animating || _shooting || _queue.isNotEmpty) return;
    if (_shown.opponent!.board[cell.$2 * 10 + cell.$1] != '.') {
      Sound.play(Sfx.error, volume: 0.5);
      add(FloatingText('ВЖЕ Є', position: _enemyCellCenter(cell.$1, cell.$2)));
      return;
    }
    _fire(cell);
  }

  Future<void> _fire((int, int) cell) async {
    _shooting = true;
    _aim = cell;
    Haptics.light();
    try {
      await game.session!.shoot(cell.$1, cell.$2);
    } on ApiException catch (e) {
      game.toast(e.message);
      Sound.play(Sfx.error);
    } finally {
      _shooting = false;
      _aim = null;
    }
  }

  @override
  void onBack() {
    if (_shown.status != 'playing') {
      game.goMenu();
      return;
    }
    game.confirm('ЗДАТИСЯ? ПЕРЕМОГА ДІСТАНЕТЬСЯ СУПЕРНИКУ.', yes: 'ЗДАТИСЯ', no: 'БИТИСЯ', onYes: () async {
      try {
        await game.session?.leave();
      } on ApiException catch (e) {
        game.toast(e.message);
      }
    });
  }

  // ---- малювання --------------------------------------------------------

  @override
  void render(Canvas canvas) {
    final v = _shown;
    final op = v.opponent!;
    final live = game.session?.view ?? v;
    final left = live.timeLeft;
    drawHeader(canvas, 'VS ${op.nickname}', right: left == null ? null : '${(left.inMilliseconds / 1000).ceil()}');

    // смуга ходу
    final mine = v.yourTurn;
    if (mine) canvas.px(0, 20, w, 14);
    final label = v.status != 'playing'
        ? 'КІНЕЦЬ БОЮ'
        : mine
            ? (_shooting ? 'ВОГОНЬ!' : 'ТВІЙ ХІД - ЦІЛЬСЯ')
            : 'ХІД СУПЕРНИКА';
    if (mine || (time * 2).floor().isEven || v.status != 'playing') {
      PixelText.draw(canvas, label, w / 2, 23, paper: mine, align: TAlign.center);
    }
    if (left != null && v.status == 'playing') {
      final k = (left.inMilliseconds / 30000).clamp(0.0, 1.0);
      canvas.px(0, 34, (w * k).floorToDouble(), 2);
    }

    // поле суперника
    canvas.save();
    canvas.translate(_enemyPos.x, _enemyPos.y);
    final shot = v.lastShot;
    _big.render(canvas, op.board, time: time, lastShot: shot != null && shot.byMe ? (shot.x, shot.y) : null);
    final aim = _aim;
    if (aim != null || (mine && !_animating)) {
      // приціл: на вибраній клітинці або "блукає", поки гравець думає
      final a = aim ?? _idleAim();
      canvas.drawImage(
        Sprites.cross[(time * 4).floor() % 2],
        Offset(_big.cellLeft(a.$1), _big.cellTop(a.$2)),
        Palette.sprite,
      );
    }
    canvas.restore();

    // флот суперника: скільки ще на плаву
    final sunkLengths = op.ships.map((s) => s.length).toList();
    var fx = _enemyPos.x + BoardStyle.big.gutter;
    final fy = _enemyPos.y + BoardStyle.big.extent + 4;
    for (final len in fleet) {
      final sunk = sunkLengths.remove(len);
      for (var k = 0; k < len; k++) {
        if (sunk) {
          canvas.pixelFrame(fx + k * 5, fy, 4, 4);
        } else {
          canvas.px(fx + k * 5, fy, 4, 4);
        }
      }
      fx += len * 5 + 4;
    }

    // своє поле
    PixelText.draw(canvas, 'ТВІЙ ФЛОТ', _minePos.x + 2, _minePos.y - 12);
    canvas.save();
    canvas.translate(_minePos.x, _minePos.y);
    _small.render(canvas, v.you.board, time: time, lastShot: shot != null && !shot.byMe ? (shot.x, shot.y) : null);
    canvas.restore();

    // журнал пострілів праворуч від свого поля: хто, клітинка, піктограма результату
    final lx = _minePos.x + _small.style.extent + 8;
    PixelText.draw(canvas, 'ЖУРНАЛ', lx, _minePos.y - 12);
    var ly = _minePos.y;
    for (var i = 0; i < _log.length; i++) {
      final (byMe, cell, result) = _log[i];
      if (ly + 12 > h - 30) break;
      final latest = i == 0;
      if (latest) canvas.px(lx - 2, ly - 2, w - lx - 2, 12);
      PixelText.draw(canvas, byMe ? 'ТИ' : 'ВІН', lx, ly, paper: latest);
      PixelText.draw(canvas, cell, lx + 32, ly, paper: latest);
      _resultIcon(canvas, w - 14, ly, result, latest);
      ly += 14;
    }
  }

  void _resultIcon(Canvas canvas, double x, double y, String result, bool paper) {
    switch (result) {
      case 'miss':
        canvas.pixelFrame(x + 1, y + 1, 6, 6, paper: paper);
      case 'hit':
        for (var k = 0; k < 8; k++) {
          canvas.px(x + k, y + k, 1, 1, paper);
          canvas.px(x + 7 - k, y + k, 1, 1, paper);
        }
      default:
        canvas.px(x, y, 8, 8, paper);
        canvas.px(x + 2, y + 2, 4, 4, !paper);
    }
  }

  // Приціл, що повільно переходить між клітинками, поки гравець думає.
  (int, int) _idleAim() {
    final t = (time * 0.8).floor();
    final board = _shown.opponent!.board;
    for (var k = 0; k < 100; k++) {
      final i = (t * 37 + k * 13) % 100;
      if (board[i] == '.') return (i % 10, i ~/ 10);
    }
    return (0, 0);
  }
}

class _FlagButton extends PositionComponent with TapCallbacks {
  final VoidCallback onTap;
  bool _down = false;

  _FlagButton({required super.position, required this.onTap}) : super(size: Vector2(64, 20));

  @override
  void render(Canvas canvas) {
    if (_down) canvas.px(0, 0, size.x, size.y);
    canvas.pixelFrame(0, 0, size.x, size.y, paper: _down);
    // білий прапор
    canvas.px(5, 4, 1, 12, _down);
    canvas.pixelFrame(6, 4, 9, 6, paper: _down);
    PixelText.draw(canvas, 'ЗДАЧА', 19, 6, paper: _down);
  }

  @override
  void onTapDown(TapDownEvent event) => _down = true;

  @override
  void onTapCancel(TapCancelEvent event) => _down = false;

  @override
  void onTapUp(TapUpEvent event) {
    _down = false;
    Sound.play(Sfx.click);
    onTap();
  }
}
