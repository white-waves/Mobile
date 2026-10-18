import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../engine/board.dart';
import '../engine/palette.dart';
import '../engine/settings.dart';
import '../engine/sprites.dart';
import '../engine/text.dart';
import '../engine/ui.dart';
import '../game/rules.dart';
import '../services/api_client.dart';
import 'scene.dart';

// Розстановка флоту: кораблі перетягуються з доку на поле.
// Тап по кораблю на полі - поворот, тап по кораблю в доці - поставити кудись.
class PlacementScene extends Scene with TapCallbacks, DragCallbacks {
  final BoardPainter _painter = BoardPainter(BoardStyle.big);
  final Map<int, Ship> _placed = {};
  late Vector2 _boardPos;
  final Map<int, Vector2> _dockPos = {};

  _Drag? _drag;
  late PixelButton _ready;
  late PixelButton _auto;
  late PixelButton _clear;
  bool _sending = false;
  int? _wobbleSlot;
  double _wobble = 0;

  static const double _lift = 22; // корабель над пальцем, щоб його було видно

  bool get _submitted => game.session?.view.you.ready ?? false;

  @override
  void build() {
    _boardPos = Vector2(((w - BoardStyle.big.extent) / 2).floorToDouble(), 36);
    // Док: кораблі в рядок із перенесенням.
    var x = 10.0;
    var y = _boardPos.y + BoardStyle.big.extent + 10;
    for (var i = 0; i < fleet.length; i++) {
      final width = fleet[i] * 16.0;
      if (x + width > w - 10) {
        x = 10;
        y += 18;
      }
      _dockPos[i] = Vector2(x, y);
      x += width + 6;
    }
    final by = h - 62;
    final half = (w - 30) / 2;
    _auto = button('АВТО', 12, by, half, _random);
    _clear = button('ОЧИСТИТИ', 18 + half, by, half, _clearAll);
    _ready = button('В БІЙ!', 12, by + 30, w - 24, null, primary: true);
  }

  // ---- геометрія -------------------------------------------------------

  Vector2 _cellPos(int x, int y) =>
      _boardPos + Vector2(_painter.cellLeft(x), _painter.cellTop(y));

  Rect _shipRect(Ship s) {
    final p = _cellPos(s.x, s.y);
    final len = s.length * 16.0;
    return Rect.fromLTWH(p.x, p.y, s.vertical ? 16 : len, s.vertical ? len : 16);
  }

  Rect _dockRect(int slot) {
    final p = _dockPos[slot]!;
    return Rect.fromLTWH(p.x, p.y, fleet[slot] * 16.0, 16);
  }

  int? _slotAt(Vector2 p) {
    final o = Offset(p.x, p.y);
    for (final e in _placed.entries) {
      if (_shipRect(e.value).inflate(2).contains(o)) return e.key;
    }
    for (var i = 0; i < fleet.length; i++) {
      if (!_placed.containsKey(i) && _dockRect(i).inflate(3).contains(o)) return i;
    }
    return null;
  }

  List<Ship> _others(int slot) => [
        for (final e in _placed.entries)
          if (e.key != slot) e.value,
      ];

  // ---- дії --------------------------------------------------------------

  void _random() {
    final ships = randomFleet();
    final slots = [for (var i = 0; i < fleet.length; i++) i];
    _placed.clear();
    for (final ship in ships) {
      final slot = slots.firstWhere((i) => fleet[i] == ship.length);
      slots.remove(slot);
      _placed[slot] = ship;
    }
    Sound.play(Sfx.select);
  }

  void _clearAll() {
    _placed.clear();
    Sound.play(Sfx.splash, volume: 0.4);
  }

  Future<void> _submit() async {
    if (_sending || _placed.length != fleet.length) return;
    _sending = true;
    try {
      await game.session!.place(_placed.values.toList());
      Sound.play(Sfx.turn);
    } on ApiException catch (e) {
      game.toast(e.message);
      Sound.play(Sfx.error);
    } finally {
      _sending = false;
    }
  }

  // Поставити корабель із доку на перше вільне місце (випадково).
  void _autoPlace(int slot) {
    final rnd = math.Random();
    for (var attempt = 0; attempt < 400; attempt++) {
      final vertical = rnd.nextBool();
      final len = fleet[slot];
      final ship = Ship(
        x: rnd.nextInt(vertical ? 10 : 11 - len),
        y: rnd.nextInt(vertical ? 11 - len : 10),
        length: len,
        vertical: vertical,
      );
      if (canPlace(_others(slot), ship)) {
        _placed[slot] = ship;
        Sound.play(Sfx.click);
        Haptics.light();
        return;
      }
    }
    _deny(slot);
  }

  void _rotate(int slot) {
    final s = _placed[slot]!;
    final vertical = !s.vertical;
    // Якщо після повороту корабель вилазить за край - зсуваємо його назад.
    final x = vertical ? s.x : math.min(s.x, 10 - s.length);
    final y = vertical ? math.min(s.y, 10 - s.length) : s.y;
    final rotated = Ship(x: x, y: y, length: s.length, vertical: vertical);
    if (canPlace(_others(slot), rotated)) {
      _placed[slot] = rotated;
      Sound.play(Sfx.select);
      Haptics.light();
    } else {
      _deny(slot);
    }
  }

  void _deny(int slot) {
    _wobbleSlot = slot;
    _wobble = 0.3;
    Sound.play(Sfx.error, volume: 0.5);
    Haptics.medium();
  }

  // ---- введення ---------------------------------------------------------

  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void onTapUp(TapUpEvent event) {
    if (_submitted) return;
    final slot = _slotAt(event.localPosition);
    if (slot == null) return;
    if (_placed.containsKey(slot)) {
      _rotate(slot);
    } else {
      _autoPlace(slot);
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_submitted) return;
    final p = event.localPosition;
    final slot = _slotAt(p);
    if (slot == null) return;
    final original = _placed.remove(slot);
    final rect = original != null ? _shipRect(original) : _dockRect(slot);
    _drag = _Drag(
      slot: slot,
      vertical: original?.vertical ?? false,
      original: original,
      grab: Vector2(p.x - rect.left, p.y - rect.top),
      finger: p.clone(),
    );
    // Корабель із доку беремо за середину першої клітинки.
    if (original == null) _drag!.grab = Vector2(8, 8);
    Sound.play(Sfx.click, volume: 0.5);
    Haptics.light();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final d = _drag;
    if (d == null) return;
    d.finger = event.localEndPosition.clone();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final d = _drag;
    _drag = null;
    if (d == null) return;
    final target = _candidate(d);
    if (target != null && canPlace(_others(d.slot), target)) {
      _placed[d.slot] = target;
      Sound.play(Sfx.splash, volume: 0.5);
      Haptics.light();
    } else if (target != null && d.original != null) {
      _placed[d.slot] = d.original!;
      _deny(d.slot);
    } else if (target != null) {
      _deny(d.slot);
    }
    // поза полем - корабель повертається в док
  }

  Vector2 _dragTopLeft(_Drag d) => d.finger - d.grab - Vector2(0, _lift);

  Ship? _candidate(_Drag d) {
    final tl = _dragTopLeft(d);
    final cx = ((tl.x - _boardPos.x - BoardStyle.big.gutter) / 16).round();
    final cy = ((tl.y - _boardPos.y - BoardStyle.big.gutter) / 16).round();
    final len = fleet[d.slot];
    final ship = Ship(x: cx, y: cy, length: len, vertical: d.vertical);
    final inside = ship.cells.where((c) => inBounds(c.$1, c.$2)).length;
    if (inside == 0) return null;
    if (inside < len) {
      // Частково над полем - підтягуємо всередину.
      final x = cx.clamp(0, d.vertical ? 9 : 10 - len);
      final y = cy.clamp(0, d.vertical ? 10 - len : 9);
      return Ship(x: x, y: y, length: len, vertical: d.vertical);
    }
    return ship;
  }

  @override
  void onBack() {
    game.confirm('ПОКИНУТИ ГРУ?', yes: 'ТАК', no: 'НІ', onYes: () async {
      try {
        await game.session?.leave();
      } on ApiException {
        // все одно виходимо
      }
      game.goMenu();
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_wobble > 0) _wobble = math.max(0, _wobble - dt);
    final submitted = _submitted;
    _ready.onPressed = !submitted && _placed.length == fleet.length && !_sending ? _submit : null;
    _auto.onPressed = submitted ? null : _random;
    _clear.onPressed = submitted ? null : _clearAll;
    _ready.label = submitted ? 'ГОТОВО' : 'В БІЙ!';
  }

  // ---- малювання --------------------------------------------------------

  void _drawShip(Canvas canvas, double x, double y, int length, bool vertical, {bool ghost = false}) {
    for (var k = 0; k < length; k++) {
      final seg = length == 1
          ? Segment.boat
          : k == 0
              ? Segment.stern
              : k == length - 1
                  ? Segment.bow
                  : Segment.mid;
      final o = Offset(x + (vertical ? 0 : k * 16.0), y + (vertical ? k * 16.0 : 0));
      canvas.drawImage(Sprites.segment(seg, vertical: vertical, sunk: ghost), o, Palette.sprite);
    }
  }

  @override
  void render(Canvas canvas) {
    final view = game.session?.view;
    final left = view?.timeLeft;
    drawHeader(canvas, 'РОЗСТАНОВКА', right: left == null ? null : '${(left.inMilliseconds / 1000).ceil()}');
    if (left != null) {
      final k = (left.inMilliseconds / 90000).clamp(0.0, 1.0);
      canvas.px(0, 19, (w * k).floorToDouble(), 2);
    }
    PixelText.draw(canvas, 'VS ${view?.opponent?.nickname ?? '?'}', w / 2, 22, align: TAlign.center);

    final submitted = _submitted;
    final ships = submitted ? view!.you.ships : _placed.values.toList();
    canvas.save();
    canvas.translate(_boardPos.x, _boardPos.y);
    final board = ownBoard(ships, emptyGrid);
    // Корабель, що "тремтить" після невдалої дії.
    if (_wobble > 0 && _wobbleSlot != null && _placed[_wobbleSlot] != null) {
      final s = _placed[_wobbleSlot]!;
      final others = ownBoard(_others(_wobbleSlot!), emptyGrid);
      _painter.render(canvas, others, time: time);
      final r = _shipRect(s);
      final dx = ((_wobble * 40).floor().isEven ? 1.0 : -1.0);
      _drawShip(canvas, r.left - _boardPos.x + dx, r.top - _boardPos.y, s.length, s.vertical);
    } else {
      _painter.render(canvas, board, time: time);
    }
    canvas.restore();

    // Док
    if (!submitted) {
      for (var i = 0; i < fleet.length; i++) {
        final p = _dockPos[i]!;
        if (_placed.containsKey(i) || _drag?.slot == i) {
          // порожнє місце в доці - пунктирний контур
          for (var k = 0.0; k < fleet[i] * 16; k += 2) {
            canvas.px(p.x + k, p.y + 15);
          }
          continue;
        }
        _drawShip(canvas, p.x, p.y, fleet[i], false);
      }
      final hintY = _dockPos.values.map((v) => v.y).reduce(math.max) + 22;
      if (hintY + 22 < h - 64) {
        PixelText.drawWrapped(canvas, 'ТЯГНИ КОРАБЛІ НА ПОЛЕ. ТАП - ПОВЕРНУТИ', 10, hintY, w - 20, lineHeight: 10);
      }
    } else {
      final y = _boardPos.y + BoardStyle.big.extent + 16;
      if ((time * 2).floor().isEven) {
        PixelText.draw(canvas, 'ЧЕКАЄМО СУПЕРНИКА', w / 2, y, align: TAlign.center);
      }
    }

    // Корабель, який тягнуть, і місце, куди він ляже
    final d = _drag;
    if (d != null) {
      final target = _candidate(d);
      if (target != null) {
        final valid = canPlace(_others(d.slot), target);
        final r = _shipRect(target);
        if (valid) {
          canvas.pixelFrame(r.left, r.top, r.width + 1, r.height + 1);
        } else {
          canvas.dither(r.left + 1, r.top + 1, r.width - 1, r.height - 1);
        }
      }
      final tl = _dragTopLeft(d);
      _drawShip(canvas, tl.x.floorToDouble(), tl.y.floorToDouble(), fleet[d.slot], d.vertical);
    }
  }
}

class _Drag {
  final int slot;
  final bool vertical;
  final Ship? original;
  Vector2 grab;
  Vector2 finger;

  _Drag({required this.slot, required this.vertical, required this.original, required this.grab, required this.finger});
}
