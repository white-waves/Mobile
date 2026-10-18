import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart' show TextInputAction, TextInputType;

import '../engine/palette.dart';
import '../engine/settings.dart';
import '../engine/text.dart';
import '../engine/ui.dart';
import '../services/api_client.dart';
import 'menu_scene.dart';
import 'scene.dart';

// Сцена-форма: поля вводу, підказка, кнопка дії. Тап поза полями ховає клавіатуру.
abstract class FormScene extends Scene with TapCallbacks {
  final List<PixelTextField> fields = [];
  String? error;
  bool busy = false;
  late PixelButton submitButton;

  String get title;
  String get submitLabel;
  String? get hint => null;
  Future<void> submit();

  PixelTextField field(String label, double y,
      {bool obscure = false, int maxLength = 64, bool upper = false, TextInputType keyboard = TextInputType.text}) {
    final f = PixelTextField(
      label: label,
      position: Vector2(12, y),
      width: w - 24,
      obscure: obscure,
      maxLength: maxLength,
      upperCase: upper,
      keyboard: keyboard,
    );
    fields.add(f);
    add(f);
    return f;
  }

  void finishFields(double buttonY) {
    for (var i = 0; i < fields.length; i++) {
      final next = i + 1 < fields.length ? fields[i + 1] : null;
      fields[i].onSubmit = next == null ? _submit : () => next.focus(action: _actionFor(i + 1));
    }
    submitButton = button(submitLabel, 12, buttonY, w - 24, _submit, primary: true);
    backButton();
  }

  TextInputAction _actionFor(int i) => i == fields.length - 1 ? TextInputAction.done : TextInputAction.next;

  Future<void> _submit() async {
    if (busy) return;
    game.input.close();
    for (final f in fields) {
      f.focused = false;
    }
    busy = true;
    error = null;
    submitButton.label = '...';
    try {
      await submit();
    } on ApiException catch (e) {
      error = e.message;
      Sound.play(Sfx.error);
      Haptics.medium();
    } finally {
      busy = false;
      submitButton.label = submitLabel;
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void onTapUp(TapUpEvent event) {
    game.input.close();
    for (final f in fields) {
      f.focused = false;
    }
  }

  @override
  void render(Canvas canvas) {
    drawHeader(canvas, title);
    final last = fields.isEmpty ? 30.0 : fields.last.position.y + 40;
    if (hint != null) PixelText.drawWrapped(canvas, hint!, 12, last, w - 24, lineHeight: 11);
    if (error != null) {
      final y = submitButton.position.y + 34;
      final lines = PixelText.wrap(error!, w - 32);
      canvas.px(8, y, w - 16, lines.length * 11 + 8.0);
      PixelText.drawWrapped(canvas, error!, 16, y + 5, w - 32, paper: true, lineHeight: 11);
    }
  }
}

class AuthScene extends FormScene {
  final bool register;
  late PixelTextField _login;
  late PixelTextField _nick;
  late PixelTextField _password;

  AuthScene({required this.register});

  @override
  String get title => register ? 'НОВИЙ КАПІТАН' : 'ВХІД';

  @override
  String get submitLabel => register ? 'ЗАПИСАТИСЬ' : 'УВІЙТИ';

  @override
  String? get hint => register ? "НІК: 3-16 ЛАТИНСЬКИХ ЛІТЕР, ЦИФР, _ АБО -" : null;

  @override
  void build() {
    var y = 30.0;
    _login = field('ЛОГІН', y, keyboard: TextInputType.emailAddress);
    y += 40;
    if (register) {
      _nick = field('НІКНЕЙМ', y, maxLength: 16);
      y += 40;
    }
    _password = field('ПАРОЛЬ', y, obscure: true);
    y += 40;
    finishFields(y + (register ? 30 : 8));
    if (!register) {
      add(MenuItem(
        label: 'НОВИЙ АКАУНТ',
        selected: () => false,
        onHover: () {},
        onSelect: () => game.show(() => AuthScene(register: true)),
        position: Vector2(12, y + 44),
        width: w - 24,
      ));
    }
  }

  @override
  Future<void> submit() async {
    final login = _login.value.trim();
    final password = _password.value;
    if (login.isEmpty || password.isEmpty) throw ApiException(0, 'ВВЕДИ ЛОГІН І ПАРОЛЬ');
    if (register) {
      if (!RegExp(r'^[A-Za-z0-9_-]{3,16}$').hasMatch(_nick.value.trim())) {
        throw ApiException(0, 'НІК: 3-16 ЛАТИНСЬКИХ ЛІТЕР АБО ЦИФР');
      }
      if (password.length < 6) throw ApiException(0, 'ПАРОЛЬ - ЩОНАЙМЕНШЕ 6 СИМВОЛІВ');
      await game.auth.register(login: login, password: password, nickname: _nick.value.trim());
    } else {
      await game.auth.login(login: login, password: password);
    }
    Sound.play(Sfx.match);
    game.show(() => MenuScene());
  }
}

class PasswordScene extends FormScene {
  late PixelTextField _old;
  late PixelTextField _new;

  @override
  String get title => 'ЗМІНА ПАРОЛЯ';

  @override
  String get submitLabel => 'ЗМІНИТИ';

  @override
  void build() {
    _old = field('СТАРИЙ ПАРОЛЬ', 30, obscure: true);
    _new = field('НОВИЙ ПАРОЛЬ', 70, obscure: true);
    finishFields(118);
  }

  @override
  Future<void> submit() async {
    if (_new.value.length < 6) throw ApiException(0, 'ПАРОЛЬ - ЩОНАЙМЕНШЕ 6 СИМВОЛІВ');
    final auth = game.auth;
    await auth.guarded(() => auth.changePassword(oldPassword: _old.value, newPassword: _new.value));
    game.toast('ПАРОЛЬ ЗМІНЕНО');
    game.goMenu();
  }
}
