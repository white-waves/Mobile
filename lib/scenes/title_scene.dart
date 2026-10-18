import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../engine/effects.dart';
import '../engine/palette.dart';
import '../engine/settings.dart';
import '../engine/text.dart';
import 'menu_scene.dart';
import 'scene.dart';

// Заставка: назва, море з кораблем, "торкнись, щоб почати".
class TitleScene extends Scene with TapCallbacks {
  @override
  void build() {
    add(SeaBackdrop(horizon: (h * 0.62).floorToDouble()));
  }

  @override
  void render(Canvas canvas) {
    final top = (h * 0.16).floorToDouble();
    // Тінь назви зсунута на 2 пікселі - класичний ретро-прийом.
    // Тінь, відступ кольором паперу, потім самі літери.
    for (final (d, paper) in [(3.0, false), (1.0, true), (0.0, false)]) {
      PixelText.draw(canvas, 'WHITE', w / 2 + d, top + d, size: 24, align: TAlign.center, paper: paper);
      PixelText.draw(canvas, 'WAVES', w / 2 + d, top + 30 + d, size: 24, align: TAlign.center, paper: paper);
    }
    PixelText.draw(canvas, 'МОРСЬКИЙ БІЙ', w / 2, top + 66, align: TAlign.center);
    canvas.px(w / 2 - 52, top + 80, 104, 1);

    if ((time * 1.6).floor().isEven) {
      PixelText.draw(canvas, 'ТОРКНИСЬ ЕКРАНУ', w / 2, h * 0.5, align: TAlign.center);
    }
    PixelText.draw(canvas, 'v2.0', w - 4, h - 12, align: TAlign.right);
  }

  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void onTapUp(TapUpEvent event) {
    Sound.play(Sfx.match);
    Haptics.medium();
    game.show(() => MenuScene());
  }
}
