import 'package:flutter_test/flutter_test.dart';
import 'package:white_waves/game/game_session.dart';
import 'package:white_waves/game/game_view.dart';
import 'package:white_waves/game/rules.dart';
import 'package:white_waves/engine/board.dart';
import 'package:white_waves/engine/sprites.dart';

void main() {
  test('random fleets follow the rules', () {
    for (var i = 0; i < 200; i++) {
      final ships = randomFleet();
      expect(ships.map((s) => s.length).toList()..sort((a, b) => b - a), fleet);
      for (var j = 0; j < ships.length; j++) {
        final others = [...ships]..removeAt(j);
        expect(canPlace(others, ships[j]), isTrue);
      }
    }
  });

  test('sinking a ship reveals the cells around it', () {
    const ships = [Ship(x: 0, y: 0, length: 2)];
    var grid = applyShot(ships, emptyGrid, 0, 0)!;
    expect(grid.result, 'hit');
    grid = applyShot(ships, grid.grid, 1, 0)!;
    expect(grid.result, 'sunk');
    expect(grid.grid.substring(0, 3), '##o');
    expect(grid.grid.substring(10, 13), 'ooo');
    expect(applyShot(ships, grid.grid, 2, 0), isNull);
    expect(allSunk(ships, grid.grid), isTrue);
  });

  test('server JSON is parsed into a game view', () {
    final view = GameView.fromJson({
      'id': 'abc',
      'status': 'playing',
      'private': false,
      'code': null,
      'you': {
        'nickname': 'me',
        'ready': true,
        'board': emptyGrid,
        'ships': [
          {'x': 0, 'y': 0, 'length': 4, 'vertical': false, 'sunk': false},
        ],
      },
      'opponent': {
        'nickname': 'foe',
        'ready': true,
        'board': emptyGrid,
        'sunkShips': [
          {'x': 5, 'y': 5, 'length': 1, 'vertical': false},
        ],
      },
      'yourTurn': true,
      'timeLeftMs': 30000,
      'lastShot': {'by': 'opponent', 'x': 3, 'y': 4, 'result': 'miss'},
      'winner': null,
      'reason': null,
    });
    expect(view.yourTurn, isTrue);
    expect(view.opponent!.ships.single.sunk, isTrue);
    expect(view.lastShot!.byMe, isFalse);
    expect(view.timeLeft!.inSeconds, greaterThan(28));
  });

  test('a full game against the hard bot finishes', () async {
    for (final level in BotLevel.values) {
      final game = LocalGameSession(nickname: 'me', level: level);
      await game.place(null);
      final bot = debugBotShips(game);
      final targets = [for (final s in bot) ...s.cells];
      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (game.view.status == 'playing' && DateTime.now().isBefore(deadline)) {
        if (game.view.yourTurn) {
          final (x, y) = targets.removeAt(0);
          await game.shoot(x, y);
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
      expect(game.view.status, 'finished');
      expect(game.view.opponent!.board.contains('S'), isFalse);
      game.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('ship shapes are recognised from the board string', () {
    const ships = [Ship(x: 0, y: 0, length: 3), Ship(x: 5, y: 5, length: 2, vertical: true), Ship(x: 9, y: 9, length: 1)];
    var board = ownBoard(ships, emptyGrid);
    var parts = shipParts(board);
    expect(parts[0]!.segment, Segment.stern);
    expect(parts[1]!.segment, Segment.mid);
    expect(parts[2]!.segment, Segment.bow);
    expect(parts[55]!.vertical, isTrue);
    expect(parts[99]!.segment, Segment.boat);
    // підбита клітинка невідомого корабля суперника - форма невідома
    board = '${'X'}${'.' * 99}';
    parts = shipParts(board);
    expect(parts[0]!.complete, isFalse);
  });
}
