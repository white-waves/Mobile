import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  // Останній рубіж: якщо щось падає повз усі локальні try/catch, застосунок
  // не має вилітати цілком - логуємо й лишаємось живими.
  runZonedGuarded(() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
    ErrorWidget.builder = (details) => const Material(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Щось пішло не так. Спробуй перезапустити застосунок.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
    runApp(const MainApp());
  }, (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
  });
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..loadSession(),
      child: MaterialApp(
        title: 'White Waves',
        theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
        home: const _RootScreen(),
      ),
    );
  }
}

class _RootScreen extends StatelessWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;
    switch (status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
