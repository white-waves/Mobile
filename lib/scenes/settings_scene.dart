import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';
import '../engine/palette.dart';
import '../engine/settings.dart';
import '../engine/text.dart';
import '../engine/ui.dart';
import 'auth_scene.dart';
import 'scene.dart';

class SettingsScene extends Scene {
  @override
  void build() {
    backButton();
    var y = 30.0;
    void toggle(String label, bool Function() get, void Function(bool) set) {
      add(PixelToggle(label: label, get: get, set: set, position: Vector2(12, y), width: w - 24));
      y += 22;
    }

    toggle('ЗВУК', () => Settings.sound, (v) {
      Settings.sound = v;
      Settings.save();
    });
    toggle('ВІБРАЦІЯ', () => Settings.vibration, (v) {
      Settings.vibration = v;
      Settings.save();
    });
    toggle('ІНВЕРСІЯ', () => Palette.inverted, (v) {
      Palette.inverted = v;
      game.applyPalette();
      Settings.save();
    });
    if (game.auth.isAuthenticated) {
      button('ЗМІНИТИ ПАРОЛЬ', 12, y + 10, w - 24, () => game.show(() => PasswordScene()));
    }
  }

  @override
  void render(Canvas canvas) {
    drawHeader(canvas, 'НАЛАШТУВАННЯ');
    PixelText.draw(canvas, 'СЕРВЕР:', 12, h - 36);
    PixelText.draw(canvas, apiBaseUrl.replaceFirst('http://', ''), 12, h - 24);
  }
}
