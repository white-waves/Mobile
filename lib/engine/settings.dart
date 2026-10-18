import 'package:flutter/services.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'palette.dart';

// Налаштування гри та звук/вібрація.
class Settings {
  static bool sound = true;
  static bool vibration = true;

  static const _storage = FlutterSecureStorage();

  static Future<void> load() async {
    try {
      sound = await _storage.read(key: 'sound') != 'off';
      vibration = await _storage.read(key: 'vibration') != 'off';
      Palette.inverted = await _storage.read(key: 'invert') == 'on';
    } catch (_) {
      // сховище недоступне - значення за замовчуванням
    }
  }

  static Future<void> save() async {
    try {
      await _storage.write(key: 'sound', value: sound ? 'on' : 'off');
      await _storage.write(key: 'vibration', value: vibration ? 'on' : 'off');
      await _storage.write(key: 'invert', value: Palette.inverted ? 'on' : 'off');
    } catch (_) {
      // не критично
    }
  }
}

enum Sfx { click, select, type, error, fire, splash, boom, sunk, turn, match, win, lose }

class Sound {
  static bool _ready = false;

  static Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll([for (final s in Sfx.values) '${s.name}.wav']);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static void play(Sfx sfx, {double volume = 0.7}) {
    if (!Settings.sound || !_ready) return;
    FlameAudio.play('${sfx.name}.wav', volume: volume).then((_) {}, onError: (_) {});
  }
}

class Haptics {
  static void light() {
    if (Settings.vibration) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (Settings.vibration) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (Settings.vibration) HapticFeedback.heavyImpact();
  }
}
