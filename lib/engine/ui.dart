// Ігрові елементи інтерфейсу, намальовані пікселями.

import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';

import '../white_waves_game.dart';
import 'input.dart';
import 'palette.dart';
import 'settings.dart';
import 'text.dart';

class PixelButton extends PositionComponent with TapCallbacks, HasGameReference<WhiteWavesGame> {
  String label;
  VoidCallback? onPressed;
  bool primary;
  final double fontSize;
  bool _down = false;

  PixelButton({
    required this.label,
    required this.onPressed,
    required Vector2 position,
    required Vector2 size,
    this.primary = false,
    this.fontSize = 8,
  }) : super(position: position, size: size);

  bool get enabled => onPressed != null;

  @override
  void render(Canvas canvas) {
    final y = _down ? 2.0 : 0.0;
    final h = size.y - 2;
    // "Тінь" - кнопка стоїть на підставці і втискається при натисканні.
    if (!_down) canvas.pixelFrame(0, 2, size.x, h);
    canvas.px(1, y + 1, size.x - 2, h - 2, !(primary && enabled));
    if (!enabled) canvas.dither(2, y + 2, size.x - 4, h - 4);
    canvas.pixelFrame(0, y, size.x, h);
    final ty = y + (h - fontSize) / 2;
    if (!enabled) {
      final w = PixelText.width(label, size: fontSize);
      canvas.px((size.x - w) / 2 - 2, ty - 2, w + 4, fontSize + 4, true);
    }
    PixelText.draw(canvas, label, size.x / 2, ty,
        size: fontSize, align: TAlign.center, paper: primary && enabled);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!enabled) {
      Sound.play(Sfx.error, volume: 0.4);
      return;
    }
    _down = true;
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!_down) return;
    _down = false;
    Sound.play(Sfx.click);
    Haptics.light();
    onPressed?.call();
  }

  @override
  void onTapCancel(TapCancelEvent event) => _down = false;
}

// Поле вводу: малюється грою, текст набирається системною клавіатурою.
class PixelTextField extends PositionComponent with TapCallbacks, HasGameReference<WhiteWavesGame> {
  final String label;
  final bool obscure;
  final int maxLength;
  final bool upperCase;
  final TextInputType keyboard;
  String value;
  VoidCallback? onSubmit;
  bool focused = false;
  double _blink = 0;

  PixelTextField({
    required this.label,
    required Vector2 position,
    required double width,
    this.obscure = false,
    this.maxLength = 64,
    this.upperCase = false,
    this.keyboard = TextInputType.text,
    this.value = '',
    this.onSubmit,
  }) : super(position: position, size: Vector2(width, 32));

  void focus({TextInputAction action = TextInputAction.next}) {
    for (final f in parent?.children.whereType<PixelTextField>() ?? const <PixelTextField>[]) {
      f.focused = false;
    }
    focused = true;
    game.input.open(InputRequest(
      initial: value,
      obscure: obscure,
      maxLength: maxLength,
      upperCase: upperCase,
      keyboard: keyboard,
      action: action,
      onChanged: (text) {
        value = upperCase ? text.toUpperCase() : text;
        Sound.play(Sfx.type, volume: 0.3);
      },
      onSubmitted: () => onSubmit?.call(),
    ));
  }

  @override
  void update(double dt) => _blink += dt;

  @override
  void render(Canvas canvas) {
    PixelText.draw(canvas, label, 0, 0);
    canvas.pixelFrame(0, 11, size.x, 20);
    if (focused) canvas.pixelFrame(-1, 10, size.x + 2, 22);
    final maxChars = ((size.x - 10) / 8).floor();
    var shown = obscure ? '*' * value.length : value;
    if (shown.length > maxChars - 1) shown = shown.substring(shown.length - maxChars + 1);
    PixelText.draw(canvas, shown, 5, 17);
    if (focused && (_blink * 2).floor().isEven) {
      canvas.px(5 + shown.length * 8, 17, 7, 8);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    Sound.play(Sfx.click, volume: 0.4);
    focus();
  }
}

class PixelToggle extends PositionComponent with TapCallbacks {
  final String label;
  bool Function() get;
  void Function(bool) set;

  PixelToggle({required this.label, required this.get, required this.set, required Vector2 position, required double width})
      : super(position: position, size: Vector2(width, 16));

  @override
  void render(Canvas canvas) {
    canvas.pixelFrame(0, 2, 12, 12);
    if (get()) canvas.px(3, 5, 6, 6);
    PixelText.draw(canvas, label, 20, 4);
  }

  @override
  void onTapUp(TapUpEvent event) {
    set(!get());
    Sound.play(Sfx.select);
    Haptics.light();
  }
}

// Пункт меню з курсором-стрілкою.
class MenuItem extends PositionComponent with TapCallbacks {
  final String label;
  final VoidCallback onSelect;
  final bool Function() selected;
  final VoidCallback onHover;
  double _t = 0;

  MenuItem({
    required this.label,
    required this.onSelect,
    required this.selected,
    required this.onHover,
    required Vector2 position,
    required double width,
  }) : super(position: position, size: Vector2(width, 18));

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final on = selected();
    if (on) {
      canvas.px(0, 0, size.x, size.y);
      // Стрілка ► "дихає".
      final dx = (_t * 4).floor().isEven ? 0.0 : 1.0;
      for (var i = 0; i < 4; i++) {
        canvas.px(4 + dx + i, 5 + i.toDouble(), 1, 8 - 2.0 * i, true);
      }
    }
    PixelText.draw(canvas, label, 16, 5, paper: on);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!selected()) {
      onHover();
      Sound.play(Sfx.select, volume: 0.5);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    Haptics.light();
    Sound.play(Sfx.click);
    onSelect();
  }
}

// Модальне вікно: перехоплює всі дотики під собою.
class ModalDialog extends PositionComponent with TapCallbacks, HasGameReference<WhiteWavesGame> {
  final String text;
  final List<(String, VoidCallback, bool)> actions;

  ModalDialog({required this.text, required this.actions}) : super(priority: 900);

  late double _boxY;
  late double _boxH;

  @override
  Future<void> onLoad() async {
    size = Vector2(game.viewW, game.viewH);
    final lines = PixelText.wrap(text, size.x - 40);
    _boxH = 24 + lines.length * 12 + actions.length * 28 + 4;
    _boxY = (size.y - _boxH) / 2;
    var by = _boxY + 18 + lines.length * 12;
    for (final (label, cb, primary) in actions) {
      add(PixelButton(
        label: label,
        primary: primary,
        position: Vector2(24, by),
        size: Vector2(size.x - 48, 24),
        onPressed: () {
          removeFromParent();
          cb();
        },
      ));
      by += 28;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.shade(0, 0, size.x, size.y);
    canvas.px(12, _boxY, size.x - 24, _boxH, true);
    canvas.pixelFrame(12, _boxY, size.x - 24, _boxH);
    canvas.pixelFrame(14, _boxY + 2, size.x - 28, _boxH - 4);
    PixelText.drawWrapped(canvas, text, 20, _boxY + 10, size.x - 40, align: TAlign.center);
  }

  @override
  bool containsLocalPoint(Vector2 point) => true;
}

// Коротке повідомлення внизу екрана.
class Toast extends PositionComponent with HasGameReference<WhiteWavesGame> {
  final String text;
  double _life = 2.2;

  Toast(this.text) : super(priority: 950);

  @override
  void update(double dt) {
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final w = game.viewW;
    final lines = PixelText.wrap(text, w - 32);
    final h = lines.length * 12 + 10.0;
    final slide = ((2.2 - _life) * 8).clamp(0, 1).toDouble();
    final y = game.viewH - 8 - h * slide;
    canvas.px(8, y, w - 16, h);
    canvas.pixelFrame(8, y, w - 16, h, paper: true);
    PixelText.drawWrapped(canvas, text, 16, y + 6, w - 32, paper: true, align: TAlign.center);
  }
}
