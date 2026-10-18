import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';

import '../engine/effects.dart';
import '../engine/palette.dart';
import '../engine/settings.dart';
import '../engine/text.dart';
import '../services/api_client.dart';
import '../white_waves_game.dart';
import 'scene.dart';

// Очікування суперника: радар або код кімнати.
class WaitScene extends Scene {
  @override
  void build() {
    final v = game.session!.view;
    if (v.isPrivate) {
      add(_CodePlate(v.code ?? '-----', position: Vector2((w - 140) / 2, 56)));
    } else {
      add(Radar(position: Vector2((w - 81) / 2, 48)));
    }
    button('СКАСУВАТИ', 12, h - 40, w - 24, _cancel);
  }

  void _cancel() async {
    try {
      await game.session?.leave();
    } on ApiException {
      // виходимо все одно
    }
    game.goMenu();
  }

  @override
  void onBack() => _cancel();

  @override
  void render(Canvas canvas) {
    final v = game.session?.view;
    final private = v?.isPrivate ?? false;
    drawHeader(canvas, private ? 'КІМНАТА' : 'ПОШУК');
    if (private) {
      PixelText.draw(canvas, 'КОД ДЛЯ ДРУГА:', w / 2, 36, align: TAlign.center);
      PixelText.draw(canvas, 'ТОРКНИСЬ - СКОПІЮВАТИ', w / 2, 102, align: TAlign.center);
      PixelText.draw(canvas, 'КОД ДІЄ 15 ХВИЛИН', w / 2, 120, align: TAlign.center);
    }
    final dots = '.' * ((time * 2).floor() % 4);
    PixelText.draw(canvas, private ? 'ЧЕКАЄМО ДРУГА$dots' : 'СКАНУЮ ОКЕАН$dots', w / 2, private ? 150 : 148,
        align: TAlign.center);
    // маленький кораблик, що гойдається
    final bob = (time * 2).floor().isEven ? 0.0 : 1.0;
    final y = h - 80 + bob;
    canvas.px(w / 2 - 12, y, 24, 3);
    canvas.px(w / 2 - 10, y + 3, 20, 2);
    canvas.px(w / 2, y - 8, 1, 8);
    canvas.px(w / 2 + 1, y - 7, 5, 4);
    canvas.px(w / 2 - 30, y + 7, 60, 1);
  }
}

class _CodePlate extends PositionComponent with TapCallbacks, HasGameReference<WhiteWavesGame> {
  final String code;

  _CodePlate(this.code, {required super.position}) : super(size: Vector2(140, 36));

  @override
  void render(Canvas canvas) {
    canvas.px(0, 0, size.x, size.y);
    canvas.pixelFrame(2, 2, size.x - 4, size.y - 4, paper: true);
    PixelText.draw(canvas, code.split('').join(' '), size.x / 2, 10, size: 16, paper: true, align: TAlign.center);
  }

  @override
  void onTapUp(TapUpEvent event) {
    Clipboard.setData(ClipboardData(text: code));
    Sound.play(Sfx.select);
    game.toast('КОД СКОПІЙОВАНО');
  }
}
