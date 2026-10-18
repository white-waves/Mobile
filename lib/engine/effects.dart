// Анімації: снаряд, вибух, бризки, банери, море, радар, феєрверк.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../white_waves_game.dart';
import 'palette.dart';
import 'sprites.dart';
import 'text.dart';

final _rnd = math.Random();

// Снаряд падає згори на ціль; тінь під ним росте.
class Shell extends PositionComponent {
  final Vector2 from;
  final Vector2 to;
  final double duration;
  final VoidCallback onImpact;
  double _t = 0;

  Shell({required this.from, required this.to, required this.onImpact, this.duration = 0.45}) : super(priority: 500);

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) {
      removeFromParent();
      onImpact();
    }
  }

  @override
  void render(Canvas canvas) {
    final k = (_t / duration).clamp(0.0, 1.0);
    final ease = k * k;
    final x = from.x + (to.x - from.x) * ease;
    final y = from.y + (to.y - from.y) * ease;
    // тінь на цілі
    final r = (1 + k * 3).floorToDouble();
    canvas.px(to.x - r, to.y + 4, r * 2, 1);
    // хвіст
    for (var i = 1; i <= 3; i++) {
      final tk = (k - i * 0.05).clamp(0.0, 1.0);
      final te = tk * tk;
      canvas.px((from.x + (to.x - from.x) * te).floorToDouble(), (from.y + (to.y - from.y) * te).floorToDouble(), 1, 1);
    }
    canvas.px(x.floorToDouble() - 1, y.floorToDouble() - 1, 3, 3);
  }
}

// Піксельний вибух: кільце, що розширюється, і уламки.
class Explosion extends PositionComponent {
  final double radius;
  double _t = 0;
  static const _life = 0.6;
  late final List<(double, double, double)> _debris = [
    for (var i = 0; i < 10; i++) (_rnd.nextDouble() * math.pi * 2, 0.5 + _rnd.nextDouble(), _rnd.nextDouble() * 0.2),
  ];

  Explosion({required Vector2 position, this.radius = 12}) : super(position: position, priority: 510);

  @override
  void update(double dt) {
    _t += dt;
    if (_t > _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final k = _t / _life;
    if (k < 0.15) {
      // спалах - суцільний квадрат
      final s = radius * 0.7;
      canvas.px(-s, -s, s * 2, s * 2);
      canvas.px(-s / 2, -s / 2, s, s, true);
      return;
    }
    final r = radius * (0.4 + k);
    for (var a = 0.0; a < math.pi * 2; a += 0.35) {
      if (k > 0.6 && (a * 10).floor().isOdd) continue;
      canvas.px((math.cos(a) * r).floorToDouble(), (math.sin(a) * r).floorToDouble(), 2, 2);
    }
    for (final (angle, speed, delay) in _debris) {
      final d = ((k - delay).clamp(0.0, 1.0)) * radius * 1.6 * speed;
      canvas.px((math.cos(angle) * d).floorToDouble(), (math.sin(angle) * d + k * k * 6).floorToDouble(), 1, 1);
    }
  }
}

// Бризки від промаху: краплі вгору і кола на воді.
class Splash extends PositionComponent {
  double _t = 0;
  static const _life = 0.55;

  Splash({required Vector2 position}) : super(position: position, priority: 510);

  @override
  void update(double dt) {
    _t += dt;
    if (_t > _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final k = _t / _life;
    final r = 2 + k * 8;
    for (var a = 0.0; a < math.pi * 2; a += 0.5) {
      canvas.px((math.cos(a) * r).floorToDouble(), (math.sin(a) * r * 0.5).floorToDouble(), 1, 1);
    }
    for (final (dx, h) in [(-3.0, 9.0), (0.0, 13.0), (3.0, 10.0)]) {
      final y = -h * math.sin(k * math.pi);
      canvas.px(dx, y.floorToDouble(), 1, 2);
    }
  }
}

// Текст, що спливає вгору і зникає.
class FloatingText extends PositionComponent {
  final String text;
  final double fontSize;
  double _t = 0;

  FloatingText(this.text, {required Vector2 position, this.fontSize = 8}) : super(position: position, priority: 520);

  @override
  void update(double dt) {
    _t += dt;
    position.y -= dt * 14;
    if (_t > 1.1) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (_t > 0.8 && (_t * 12).floor().isEven) return;
    final w = PixelText.width(text, size: fontSize);
    canvas.px(-w / 2 - 3, -3, w + 6, fontSize + 6, true);
    canvas.pixelFrame(-w / 2 - 3, -3, w + 6, fontSize + 6);
    PixelText.draw(canvas, text, 0, 0, size: fontSize, align: TAlign.center);
  }
}

// Банер через увесь екран: виїжджає, тримається, від'їжджає.
class Banner extends PositionComponent with HasGameReference<WhiteWavesGame> {
  final String text;
  double _t = 0;
  static const _life = 1.3;

  Banner(this.text, {required double y}) : super(position: Vector2(0, y), priority: 600);

  @override
  void update(double dt) {
    _t += dt;
    if (_t > _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final w = game.viewW;
    double x;
    if (_t < 0.2) {
      x = -w + w * (_t / 0.2);
    } else if (_t > _life - 0.2) {
      x = w * ((_t - (_life - 0.2)) / 0.2);
    } else {
      x = 0;
    }
    x = x.floorToDouble();
    canvas.px(x, 0, w, 28);
    canvas.px(x, 2, w, 1, true);
    canvas.px(x, 25, w, 1, true);
    PixelText.draw(canvas, text, x + w / 2, 6, size: 16, paper: true, align: TAlign.center);
  }
}

// Анімоване море з хмарами і кораблем - тло для меню.
class SeaBackdrop extends PositionComponent with HasGameReference<WhiteWavesGame> {
  final double horizon;
  final bool ship;
  double _t = 0;

  SeaBackdrop({required this.horizon, this.ship = true}) : super(priority: -10);

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final w = game.viewW;
    final h = game.viewH;
    // хмари
    for (var i = 0; i < 3; i++) {
      final cx = ((i * 83 + _t * (3 + i)) % (w + 60)) - 30;
      final cy = horizon - 60 - i * 22.0;
      _cloud(canvas, cx.floorToDouble(), cy);
    }
    // лінія горизонту
    canvas.px(0, horizon, w, 1);
    // хвилі: ряди, що рухаються з різною швидкістю
    final frame = (_t * 6).floor();
    for (var row = 0; horizon + 6 + row * 9 < h; row++) {
      final y = horizon + 6 + row * 9;
      final shift = (frame * (row.isEven ? 1 : -1) * (1 + row % 3)) % 24;
      for (var x = -24.0 + shift; x < w; x += 24) {
        final xx = (x + (row * 7) % 24).floorToDouble();
        canvas.px(xx, y + 1, 1, 1);
        canvas.px(xx + 1, y, 3, 1);
        canvas.px(xx + 4, y + 1, 1, 1);
        if (row > 2) canvas.px(xx + 10, y + 4, 2, 1);
      }
    }
    if (ship) {
      final sx = ((_t * 6) % (w + 80)) - 40;
      final bob = ((_t * 2).floor() % 2).toDouble();
      final img = Sprites.segment(Segment.boat);
      canvas.save();
      canvas.translate(sx.floorToDouble(), horizon - 18 + bob);
      canvas.scale(2);
      canvas.drawImage(img, Offset.zero, Palette.sprite);
      canvas.restore();
      // кільватер
      canvas.px(sx.floorToDouble() - 6, horizon + 2, 5, 1);
      canvas.px(sx.floorToDouble() - 12, horizon + 3, 4, 1);
    }
  }

  void _cloud(Canvas c, double x, double y) {
    c.px(x + 4, y, 10, 1);
    c.px(x + 2, y + 1, 16, 1);
    c.px(x, y + 2, 24, 1);
    c.px(x + 2, y + 3, 18, 1);
  }
}

// Радар під час пошуку суперника.
class Radar extends PositionComponent {
  double _t = 0;
  final List<(double, double, double)> _blips = [];

  Radar({required Vector2 position}) : super(position: position, size: Vector2.all(81));

  @override
  void update(double dt) {
    _t += dt;
    for (var i = _blips.length - 1; i >= 0; i--) {
      final b = _blips[i];
      if (_t - b.$3 > 1.5) _blips.removeAt(i);
    }
    if (_rnd.nextDouble() < dt * 1.2) {
      final a = _t * 2.2;
      final r = 8 + _rnd.nextDouble() * 28;
      _blips.add((40 + math.cos(a) * r, 40 + math.sin(a) * r, _t));
    }
  }

  @override
  void render(Canvas canvas) {
    const c = 40.0;
    for (var a = 0; a < 360; a += 3) {
      final rad = a * math.pi / 180;
      for (final r in [40.0, 27.0, 14.0]) {
        if (r != 40 && a % 9 != 0) continue;
        canvas.px((c + math.cos(rad) * r).roundToDouble(), (c + math.sin(rad) * r).roundToDouble());
      }
    }
    final angle = (_t * 2.2 * 20).floor() / 20;
    for (var k = 0; k < 5; k++) {
      final rad = angle - k * 0.09;
      for (var r = 0.0; r < 40; r += k + 1) {
        canvas.px((c + math.cos(rad) * r).roundToDouble(), (c + math.sin(rad) * r).roundToDouble());
      }
    }
    for (final (x, y, born) in _blips) {
      if (((_t - born) * 6).floor().isEven) canvas.px(x.roundToDouble() - 1, y.roundToDouble() - 1, 3, 3);
    }
  }
}

// Феєрверк для перемоги.
class Fireworks extends PositionComponent with HasGameReference<WhiteWavesGame> {
  final List<_Burst> _bursts = [];
  double _t = 0;
  double _next = 0;

  Fireworks() : super(priority: 5);

  @override
  void update(double dt) {
    _t += dt;
    if (_t > _next) {
      _next = _t + 0.35 + _rnd.nextDouble() * 0.5;
      _bursts.add(_Burst(
        16 + _rnd.nextDouble() * (game.viewW - 32),
        30 + _rnd.nextDouble() * 90,
        _t,
      ));
    }
    _bursts.removeWhere((b) => _t - b.born > 1.2);
  }

  @override
  void render(Canvas canvas) {
    for (final b in _bursts) {
      final k = (_t - b.born) / 1.2;
      final r = 4 + k * 20;
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        final fall = k * k * 10;
        if (k > 0.7 && (i + (_t * 10).floor()).isOdd) continue;
        canvas.px((b.x + math.cos(a) * r).floorToDouble(), (b.y + math.sin(a) * r + fall).floorToDouble(), 2, 2);
      }
    }
  }
}

class _Burst {
  final double x;
  final double y;
  final double born;

  _Burst(this.x, this.y, this.born);
}
