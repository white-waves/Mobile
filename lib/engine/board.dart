// Відмальовування поля 10x10 зі спрайтами.
//
// Форма кораблів визначається прямо з рядка поля: кораблі ніколи не
// торкаються, тож кожна зв'язна група клітинок 'S', 'X', '#' - це один
// корабель. Група лише з 'X' - підбитий корабель суперника, чию форму
// ще не видно: малюємо уламки, що горять.

import 'dart:ui';

import '../game/rules.dart';
import 'palette.dart';
import 'sprites.dart';

const Map<String, List<String>> _glyphs = {
  'A': ['.#.', '#.#', '###', '#.#', '#.#'],
  'B': ['##.', '#.#', '##.', '#.#', '##.'],
  'C': ['.##', '#..', '#..', '#..', '.##'],
  'D': ['##.', '#.#', '#.#', '#.#', '##.'],
  'E': ['###', '#..', '##.', '#..', '###'],
  'F': ['###', '#..', '##.', '#..', '#..'],
  'G': ['.##', '#..', '#.#', '#.#', '.##'],
  'H': ['#.#', '#.#', '###', '#.#', '#.#'],
  'I': ['###', '.#.', '.#.', '.#.', '###'],
  'J': ['..#', '..#', '..#', '#.#', '.#.'],
  '0': ['###', '#.#', '#.#', '#.#', '###'],
  '1': ['.#.', '##.', '.#.', '.#.', '###'],
  '2': ['##.', '..#', '.#.', '#..', '###'],
  '3': ['##.', '..#', '.#.', '..#', '##.'],
  '4': ['#.#', '#.#', '###', '..#', '..#'],
  '5': ['###', '#..', '##.', '..#', '##.'],
  '6': ['.##', '#..', '###', '#.#', '###'],
  '7': ['###', '..#', '.#.', '.#.', '.#.'],
  '8': ['###', '#.#', '###', '#.#', '###'],
  '9': ['###', '#.#', '###', '..#', '##.'],
};

void drawTinyText(Canvas canvas, String text, double x, double y) {
  for (var i = 0; i < text.length; i++) {
    final g = _glyphs[text[i]];
    if (g == null) continue;
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 3; c++) {
        if (g[r][c] == '#') canvas.px(x + i * 4 + c, y + r);
      }
    }
  }
}

class CellPart {
  final Segment segment;
  final bool vertical;
  final bool complete; // форма корабля відома

  const CellPart(this.segment, this.vertical, this.complete);
}

// Для кожної клітинки корабля - яким сегментом її малювати.
Map<int, CellPart> shipParts(String board) {
  const shipMarks = {'S', 'X', '#'};
  final parts = <int, CellPart>{};
  final seen = <int>{};
  for (var i = 0; i < 100; i++) {
    if (!shipMarks.contains(board[i]) || seen.contains(i)) continue;
    final group = <int>[];
    final stack = [i];
    seen.add(i);
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      group.add(c);
      final x = c % 10;
      final y = c ~/ 10;
      for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = x + dx;
        final ny = y + dy;
        final n = ny * 10 + nx;
        if (inBounds(nx, ny) && !seen.contains(n) && shipMarks.contains(board[n])) {
          seen.add(n);
          stack.add(n);
        }
      }
    }
    group.sort();
    final complete = group.any((c) => board[c] != 'X');
    final vertical = group.length > 1 && group[1] - group[0] == 10;
    for (var k = 0; k < group.length; k++) {
      final segment = group.length == 1
          ? Segment.boat
          : k == 0
              ? Segment.stern
              : k == group.length - 1
                  ? Segment.bow
                  : Segment.mid;
      parts[group[k]] = CellPart(segment, vertical, complete);
    }
  }
  return parts;
}

class BoardStyle {
  final double cell;
  final double gutter;

  const BoardStyle(this.cell, this.gutter);

  static const big = BoardStyle(16, 7);
  static const medium = BoardStyle(12, 7);
  static const small = BoardStyle(8, 7);

  double get extent => gutter + cell * boardSize + 1;
}

class BoardPainter {
  final BoardStyle style;

  BoardPainter(this.style);

  // Номер клітинки за локальною точкою або null.
  (int, int)? cellAt(double lx, double ly) {
    final x = ((lx - style.gutter) / style.cell).floor();
    final y = ((ly - style.gutter) / style.cell).floor();
    return inBounds(x, y) ? (x, y) : null;
  }

  double cellLeft(int x) => style.gutter + x * style.cell;
  double cellTop(int y) => style.gutter + y * style.cell;

  void render(
    Canvas canvas,
    String board, {
    required double time,
    (int, int)? lastShot,
    Set<int> hidden = const {},
  }) {
    final c = style.cell;
    final g = style.gutter;
    for (var i = 0; i < boardSize; i++) {
      drawTinyText(canvas, 'ABCDEFGHIJ'[i], g + i * c + (c - 3) / 2 + 1, 0);
      final n = '${i + 1}';
      drawTinyText(canvas, n, g - 2 - n.length * 4, g + i * c + (c - 5) / 2 + 1);
    }
    if (style.cell >= 16) {
      _renderBig(canvas, board, time, hidden);
    } else {
      _renderSmall(canvas, board, hidden);
    }
    final ext = style.extent;
    canvas.px(g, g, ext - g, 1);
    canvas.px(g, ext - 1, ext - g, 1);
    canvas.px(g, g, 1, ext - g);
    canvas.px(ext - 1, g, 1, ext - g);

    if (lastShot != null && (time * 3).floor().isEven) {
      final lx = g + lastShot.$1 * c - 1;
      final ly = g + lastShot.$2 * c - 1;
      canvas.px(lx, ly, c + 3, 1);
      canvas.px(lx, ly + c + 2, c + 3, 1);
      canvas.px(lx, ly, 1, c + 3);
      canvas.px(lx + c + 2, ly, 1, c + 3);
    }
  }

  void _renderBig(Canvas canvas, String board, double time, Set<int> hidden) {
    final g = style.gutter;
    final parts = shipParts(board);
    final waveFrame = (time * 4).floor();
    final fireFrame = (time * 8).floor();
    for (var y = 0; y < boardSize; y++) {
      for (var x = 0; x < boardSize; x++) {
        final i = y * 10 + x;
        final o = Offset(g + x * 16.0, g + y * 16.0);
        // Хвильки лише в частині клітинок - так поле читається спокійніше.
        final wavy = (x * 7 + y * 3) % 3 == 0;
        canvas.drawImage(wavy ? Sprites.water[(waveFrame + x + y * 3) % 8] : Sprites.calmWater, o, Palette.sprite);
        final mark = hidden.contains(i) ? '.' : board[i];
        if (mark == 'o') {
          canvas.drawImage(Sprites.buoy, o, Palette.sprite);
          continue;
        }
        final part = parts[i];
        if (part == null || mark == '.') continue;
        if (!part.complete) {
          canvas.drawImage(Sprites.debris, o, Palette.sprite);
          canvas.drawImage(Sprites.fire[(fireFrame + x) % 3], o, Palette.sprite);
          continue;
        }
        final sunk = mark == '#';
        canvas.drawImage(Sprites.segment(part.segment, vertical: part.vertical, sunk: sunk), o, Palette.sprite);
        if (mark == 'X') {
          canvas.drawImage(part.vertical ? Sprites.holesV : Sprites.holesH, o, Palette.sprite);
          canvas.drawImage(Sprites.fire[(fireFrame + x + y) % 3], o, Palette.sprite);
        }
      }
    }
  }

  // Спрощене поле (8 чи 12 пікселів на клітинку) без спрайтів.
  void _renderSmall(Canvas canvas, String board, Set<int> hidden) {
    final g = style.gutter;
    final c = style.cell;
    final n = c - 1; // розмір вмісту клітинки
    for (var t = g; t <= g + c * 10; t += 2) {
      for (var k = 1; k < 10; k++) {
        canvas.px(t, g + k * c);
        canvas.px(g + k * c, t);
      }
    }
    const marks = {'S', 'X', '#'};
    for (var y = 0; y < 10; y++) {
      for (var x = 0; x < 10; x++) {
        final i = y * 10 + x;
        final mark = board[i];
        final ox = g + x * c + 1;
        final oy = g + y * c + 1;
        switch (mark) {
          case 'o':
            final d = (n / 2).floorToDouble() - 1;
            canvas.px(ox + d, oy + d, 3, 3);
            if (c >= 12) canvas.px(ox + d + 1, oy + d + 1, 1, 1, true);
          case 'S':
            canvas.px(ox, oy, n, n);
          case 'X':
            canvas.px(ox, oy, n, n);
            for (var k = 1; k < n - 1; k++) {
              canvas.px(ox + k, oy + k, 1, 1, true);
              canvas.px(ox + n - 1 - k, oy + k, 1, 1, true);
            }
          case '#':
            canvas.dither(ox, oy, n, n);
        }
        if (marks.contains(mark)) {
          if (x < 9 && marks.contains(board[i + 1])) canvas.px(ox + n, oy + 1, 1, n - 2);
          if (y < 9 && marks.contains(board[i + 10])) canvas.px(ox + 1, oy + n, n - 2, 1);
        }
      }
    }
  }
}
