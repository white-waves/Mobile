import 'dart:ui';

import 'package:flame/components.dart';

import '../engine/palette.dart';
import '../engine/text.dart';
import '../engine/ui.dart';
import '../white_waves_game.dart';

// Базова сцена: займає весь піксельний екран гри.
abstract class Scene extends PositionComponent with HasGameReference<WhiteWavesGame> {
  double time = 0;

  double get w => game.viewW;
  double get h => game.viewH;

  @override
  Future<void> onLoad() async {
    size = Vector2(w, h);
    build();
  }

  // Розставляє дочірні компоненти; викликається після того, як відомий розмір.
  void build() {}

  void onBack() => game.goMenu();

  @override
  void update(double dt) => time += dt;

  // Заголовок сцени: інвертована смуга зверху.
  void drawHeader(Canvas canvas, String title, {String? right}) {
    canvas.px(0, 0, w, 18);
    PixelText.draw(canvas, title, 8, 5, paper: true);
    if (right != null) PixelText.draw(canvas, right, w - 8, 5, paper: true, align: TAlign.right);
  }

  PixelButton button(String label, double x, double y, double width, VoidCallback? onPressed,
      {bool primary = false, double height = 24}) {
    final b = PixelButton(
      label: label,
      onPressed: onPressed,
      primary: primary,
      position: Vector2(x, y),
      size: Vector2(width, height),
    );
    add(b);
    return b;
  }

  // Кнопка "назад" у правому верхньому куті смуги заголовка.
  void backButton() {
    add(_BackArrow(position: Vector2(w - 22, 1), onTap: onBack));
  }
}

class _BackArrow extends PixelButton {
  _BackArrow({required super.position, required VoidCallback onTap})
      : super(label: '', onPressed: onTap, size: Vector2(20, 16));

  @override
  void render(Canvas canvas) {
    // "x" у рамці, у кольорі паперу на чорнильній смузі
    canvas.pixelFrame(2, 1, 16, 14, paper: true);
    for (var i = 0; i < 6; i++) {
      canvas.px(7 + i.toDouble(), 5 + i.toDouble(), 1, 1, true);
      canvas.px(12 - i.toDouble(), 5 + i.toDouble(), 1, 1, true);
    }
  }
}
