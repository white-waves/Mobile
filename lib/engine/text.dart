import 'package:flutter/painting.dart';

import 'palette.dart';

const String pixelFont = 'PressStart2P';

enum TAlign { left, center, right }

// Текст шрифтом Press Start 2P: розмір 8 - рівно один піксель шрифту
// на один піксель гри, 16 і 24 - удвічі й утричі більші.
class PixelText {
  static final Map<(String, double, bool), TextPainter> _cache = {};

  static double width(String text, {double size = 8}) => text.length * size;

  static void clearCache() => _cache.clear();

  static void draw(
    Canvas canvas,
    String text,
    double x,
    double y, {
    double size = 8,
    bool paper = false,
    TAlign align = TAlign.left,
  }) {
    if (text.isEmpty) return;
    final key = (text, size, paper != Palette.inverted);
    var painter = _cache[key];
    if (painter == null) {
      if (_cache.length > 400) _cache.clear();
      painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: pixelFont,
            fontSize: size,
            height: 1,
            color: paper ? Palette.paper : Palette.ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _cache[key] = painter;
    }
    final w = width(text, size: size);
    final left = switch (align) {
      TAlign.left => x,
      TAlign.center => x - w / 2,
      TAlign.right => x - w,
    };
    painter.paint(canvas, Offset(left.roundToDouble(), y.roundToDouble()));
  }

  // Перенесення за словами під ширину (моноширинний шрифт).
  static List<String> wrap(String text, double maxWidth, {double size = 8}) {
    final perLine = (maxWidth / size).floor().clamp(1, 1000);
    final lines = <String>[];
    for (final paragraph in text.split('\n')) {
      var line = '';
      for (final word in paragraph.split(' ')) {
        if (line.isEmpty) {
          line = word;
        } else if (line.length + 1 + word.length <= perLine) {
          line = '$line $word';
        } else {
          lines.add(line);
          line = word;
        }
        while (line.length > perLine) {
          lines.add(line.substring(0, perLine));
          line = line.substring(perLine);
        }
      }
      lines.add(line);
    }
    return lines;
  }

  static double drawWrapped(
    Canvas canvas,
    String text,
    double x,
    double y,
    double maxWidth, {
    double size = 8,
    double lineHeight = 12,
    TAlign align = TAlign.left,
    bool paper = false,
  }) {
    var cy = y;
    for (final line in wrap(text, maxWidth, size: size)) {
      final lx = align == TAlign.center ? x + maxWidth / 2 : x;
      draw(canvas, line, lx, cy, size: size, align: align, paper: paper);
      cy += lineHeight;
    }
    return cy;
  }
}
