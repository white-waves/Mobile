import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

import 'engine/input.dart';
import 'engine/palette.dart';
import 'engine/settings.dart';
import 'engine/sprites.dart';
import 'engine/text.dart';
import 'engine/ui.dart';
import 'game/game_session.dart';
import 'game/game_view.dart';
import 'providers/auth_provider.dart';
import 'scenes/battle_scene.dart';
import 'scenes/menu_scene.dart';
import 'scenes/placement_scene.dart';
import 'scenes/result_scene.dart';
import 'scenes/scene.dart';
import 'scenes/title_scene.dart';
import 'scenes/wait_scene.dart';
import 'services/api_client.dart';

// Гра живе у "віртуальному" піксельному екрані шириною ~200-240 пікселів.
// Він масштабується цілим множником у фізичних пікселях пристрою,
// тож кожен піксель гри - рівний квадрат без розмиття.
class WhiteWavesGame extends FlameGame {
  final AuthProvider auth = AuthProvider();
  final TextInputBridge input = TextInputBridge();

  double viewW = 216;
  double viewH = 444;
  late final _PixelRoot _root = _PixelRoot();
  Scene? _scene;
  Scene Function()? _sceneFactory;
  _Wipe? _wipe;
  double _shake = 0;

  GameSession? session;
  Future<GameSession> Function()? _replay;

  @override
  Color backgroundColor() => Palette.paper;

  @override
  Future<void> onLoad() async {
    // Жоден із цих кроків не має права "підвісити" запуск гри.
    const limit = Duration(seconds: 4);
    await Settings.load().timeout(limit, onTimeout: () {});
    Sprites.build();
    await Sound.preload().timeout(limit, onTimeout: () {});
    await auth.loadSession().timeout(limit, onTimeout: () {});
    add(_root);
    show(() => TitleScene(), wipe: false);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final physW = size.x * dpr;
    final physH = size.y * dpr;
    // Ширина гри ~200+ пікселів, висота - не менше 380.
    var scale = math.max(1, (physW / 200).floor());
    while (scale > 1 && physH / scale < 380) {
      scale--;
    }
    final newW = (physW / scale).floorToDouble();
    final newH = (physH / scale).floorToDouble();
    final zoom = scale / dpr;
    _root.scale = Vector2.all(zoom);
    // зсув по центру, вирівняний до фізичного пікселя
    _root.position = Vector2(
      ((physW - newW * scale) / 2).floorToDouble() / dpr,
      ((physH - newH * scale) / 2).floorToDouble() / dpr,
    );
    _root.basePosition = _root.position.clone();
    final changed = newW != viewW || newH != viewH;
    viewW = newW;
    viewH = newH;
    _root.size = Vector2(viewW, viewH);
    if (changed && _scene != null && _sceneFactory != null && isLoaded) {
      _replaceScene(_sceneFactory!());
    }
  }

  // ---- Сцени -----------------------------------------------------------

  Scene? get scene => _scene;

  void show(Scene Function() factory, {bool wipe = true}) {
    input.close();
    _sceneFactory = factory;
    if (!wipe || _scene == null) {
      _replaceScene(factory());
      return;
    }
    _wipe?.removeFromParent();
    _wipe = _Wipe(onCovered: () => _replaceScene(factory()));
    _root.add(_wipe!);
  }

  void _replaceScene(Scene next) {
    _scene?.removeFromParent();
    _scene = next;
    _root.add(next);
  }

  void goMenu() {
    endSession();
    show(() => MenuScene());
  }

  void toast(String text) {
    _root.children.whereType<Toast>().forEach((t) => t.removeFromParent());
    _root.add(Toast(text));
  }

  void confirm(String text, {required String yes, required String no, required VoidCallback onYes}) {
    input.close();
    _root.add(ModalDialog(text: text, actions: [(yes, onYes, true), (no, () {}, false)]));
  }

  void shake([double strength = 0.3]) => _shake = math.max(_shake, strength);

  void handleBack() {
    final modal = _root.children.whereType<ModalDialog>().firstOrNull;
    if (modal != null) {
      modal.removeFromParent();
      return;
    }
    if (input.isOpen) {
      input.close();
      return;
    }
    if (_scene is TitleScene) {
      SystemNavigator.pop();
      return;
    }
    _scene?.onBack();
  }

  void applyPalette() {
    Sprites.build();
    PixelText.clearCache();
  }

  // ---- Ігрова сесія ----------------------------------------------------

  // Запускає гру (онлайн чи з ботом). start можна повторити для "Ще раз".
  Future<void> startGame(Future<GameSession> Function() start) async {
    try {
      final s = await start();
      endSession();
      session = s;
      _replay = start;
      s.addListener(_onSession);
      _route(s.view, initial: true);
    } on ApiException catch (e) {
      toast(e.message);
      Sound.play(Sfx.error);
    }
  }

  void replay() {
    final start = _replay;
    if (start == null) {
      goMenu();
    } else {
      startGame(start);
    }
  }

  void endSession() {
    session?.removeListener(_onSession);
    session?.dispose();
    session = null;
  }

  void _onSession() {
    final s = session;
    if (s == null) return;
    _route(s.view);
  }

  void _route(GameView v, {bool initial = false}) {
    final current = _scene;
    switch (v.status) {
      case 'waiting':
        if (current is! WaitScene) show(() => WaitScene());
      case 'placing':
        if (current is! PlacementScene) {
          if (!initial) {
            Sound.play(Sfx.match);
            Haptics.heavy();
          }
          show(() => PlacementScene());
        }
      case 'playing':
        if (current is! BattleScene) show(() => BattleScene());
      default:
        // Бій сам показує фінал після останніх анімацій.
        if (current is! BattleScene && current is! ResultScene) show(() => ResultScene(v));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_shake > 0) {
      _shake = math.max(0, _shake - dt);
      final zoom = _root.scale.x;
      final amp = (_shake * 10).ceilToDouble();
      _root.position = _root.basePosition +
          Vector2(
            (math.Random().nextDouble() * 2 - 1) * amp * zoom,
            (math.Random().nextDouble() * 2 - 1) * amp * zoom,
          );
      if (_shake == 0) _root.position = _root.basePosition.clone();
    }
  }
}

class _PixelRoot extends PositionComponent {
  Vector2 basePosition = Vector2.zero();

  @override
  void render(Canvas canvas) {
    canvas.px(-4000, -4000, 8000 + size.x, 8000 + size.y, true);
  }
}

// Перехід між сценами: екран заповнюється блоками 8x8 у випадковому
// порядку, сцена міняється, блоки зникають.
class _Wipe extends PositionComponent with HasGameReference<WhiteWavesGame> {
  final VoidCallback onCovered;
  double _t = 0;
  bool _swapped = false;
  late final List<int> _order;
  late final int _cols;
  late final int _rows;
  static const _half = 0.22;

  _Wipe({required this.onCovered}) : super(priority: 1000);

  @override
  Future<void> onLoad() async {
    _cols = (game.viewW / 8).ceil();
    _rows = (game.viewH / 8).ceil();
    _order = List.generate(_cols * _rows, (i) => i)..shuffle(math.Random(7));
  }

  @override
  void update(double dt) {
    _t += dt;
    if (!_swapped && _t >= _half) {
      _swapped = true;
      onCovered();
    }
    if (_t >= _half * 2) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final k = _t < _half ? _t / _half : 1 - (_t - _half) / _half;
    final n = (k.clamp(0.0, 1.0) * _order.length).floor();
    for (var i = 0; i < n; i++) {
      final cell = _order[i];
      canvas.px((cell % _cols) * 8.0, (cell ~/ _cols) * 8.0, 8, 8);
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) => true;
}
