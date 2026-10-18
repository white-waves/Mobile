import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine/input.dart';
import 'white_waves_game.dart';

void main() {
  // Останній рубіж: якщо щось падає повз усі локальні try/catch, гра
  // не має вилітати цілком - логуємо й лишаємось живими.
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
    // Не чекаємо: на деяких пристроях ці виклики відповідають із затримкою.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    runApp(const WhiteWavesApp());
  }, (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
  });
}

class WhiteWavesApp extends StatefulWidget {
  const WhiteWavesApp({super.key});

  @override
  State<WhiteWavesApp> createState() => _WhiteWavesAppState();
}

class _WhiteWavesAppState extends State<WhiteWavesApp> with WidgetsBindingObserver {
  final WhiteWavesGame _game = WhiteWavesGame();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    keepImmersive(_game.input);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) restoreImmersive();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'White Waves',
      debugShowCheckedModeBanner: false,
      home: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _game.handleBack();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: false,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: GameWidget(game: _game)),
              HiddenTextInput(bridge: _game.input),
            ],
          ),
        ),
      ),
    );
  }
}
