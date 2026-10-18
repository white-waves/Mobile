import 'dart:ui';

// 1-бітна палітра: лише "чорнило" і "папір". Інверсія міняє їх місцями.
class Palette {
  static const Color _light = Color(0xFFF2F2F2);
  static const Color _dark = Color(0xFF0A0A0A);

  static bool inverted = false;

  static Color get ink => inverted ? _dark : _light;
  static Color get paper => inverted ? _light : _dark;

  static final Paint _inkPaint = Paint()..isAntiAlias = false;
  static final Paint _paperPaint = Paint()..isAntiAlias = false;

  static Paint get inkPaint => _inkPaint..color = ink;
  static Paint get paperPaint => _paperPaint..color = paper;

  // Для зображень-спрайтів: без згладжування при масштабуванні.
  static final Paint sprite = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
}

// Малювання "пікселями" гри (координати вже в ігрових пікселях).
extension PixelCanvas on Canvas {
  void px(double x, double y, [double w = 1, double h = 1, bool paper = false]) {
    drawRect(Rect.fromLTWH(x, y, w, h), paper ? Palette.paperPaint : Palette.inkPaint);
  }

  // Рамка товщиною 1 піксель зі "зрізаними" кутами.
  void pixelFrame(double x, double y, double w, double h, {bool paper = false}) {
    px(x + 1, y, w - 2, 1, paper);
    px(x + 1, y + h - 1, w - 2, 1, paper);
    px(x, y + 1, 1, h - 2, paper);
    px(x + w - 1, y + 1, 1, h - 2, paper);
  }

  // Розріджена сітка (1 з 8 пікселів) - "затемнення" під модальними вікнами.
  void shade(double x, double y, double w, double h) {
    for (var j = 0.0; j < h; j += 2) {
      for (var i = (j / 2) % 2 * 2; i < w; i += 4) {
        px(x + i, y + j);
      }
    }
  }

  // Шахове розсіювання (50%) - єдиний "сірий" у 1-бітній графіці.
  void dither(double x, double y, double w, double h, {int phase = 0}) {
    for (var j = 0; j < h; j++) {
      for (var i = (j + phase) % 2; i < w; i += 2) {
        px(x + i, y + j);
      }
    }
  }
}
