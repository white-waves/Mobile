# Mobile
📱 • Official mobile client for White Waves game.

A game on the [Flame](https://flame-engine.org) engine (Flutter), Android / iOS, portrait.
Pixel monochrome style: the game draws on a virtual screen about 216 pixels wide and scales it
by a whole number, so every pixel is a sharp square. Font: Press Start 2P (SIL OFL).

Online games, games with a friend by code, an offline bot (two levels), leaderboard.

```sh
flutter pub get
flutter run --dart-define=API_URL=http://192.168.0.1:3000   # without API_URL: the production server
flutter test
```

- `lib/white_waves_game.dart`: the game: pixel scaling, scenes and transitions, the game session
- `lib/scenes/`: scenes (title, menu, forms, placement, battle, result, leaderboard...)
- `lib/engine/`: palette, sprites drawn in code, board, effects, UI elements, sound
- `lib/game/`: rules, the game state model, sessions (online over REST + WebSocket, local with a bot)
- `assets/audio/`: 8-bit sound effects
