import 'dart:ui';

import '../engine/palette.dart';
import '../engine/text.dart';
import '../engine/ui.dart';
import '../game/game_session.dart';
import '../services/api_client.dart';
import 'auth_scene.dart';

// Гра з другом: створити кімнату або ввести код.
class FriendScene extends FormScene {
  late PixelTextField _code;

  @override
  String get title => 'З ДРУГОМ';

  @override
  String get submitLabel => 'ПРИЄДНАТИСЯ';

  @override
  void build() {
    button('СТВОРИТИ КІМНАТУ', 12, 54, w - 24, _create, primary: true);
    _code = field('КОД КІМНАТИ', 120, maxLength: 5, upper: true);
    finishFields(166);
  }

  void _create() {
    final auth = game.auth;
    game.startGame(() async => OnlineGameSession(
          api: auth.api,
          token: auth.token!,
          mode: GameMode.room,
          initial: await auth.guarded(() => auth.api.createRoom(auth.token!)),
        ));
  }

  @override
  Future<void> submit() async {
    final code = _code.value.trim();
    if (code.length != 5) throw ApiException(0, 'КОД МАЄ 5 СИМВОЛІВ');
    final auth = game.auth;
    await game.startGame(() async => OnlineGameSession(
          api: auth.api,
          token: auth.token!,
          mode: GameMode.room,
          initial: await auth.guarded(() => auth.api.joinRoom(auth.token!, code)),
        ));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    PixelText.drawWrapped(canvas, 'СТВОРИ КІМНАТУ І ПЕРЕДАЙ КОД ДРУГОВІ', 12, 26, w - 24, lineHeight: 11);
    canvas.px(12, 98, w - 24, 1);
    PixelText.draw(canvas, 'АБО', w / 2, 94, align: TAlign.center);
  }
}
