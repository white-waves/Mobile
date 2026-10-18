// Правила "Морського бою" - ті самі, що й на сервері (Server/services/battleship.js).
//
// Поле 10x10, клітинка (x, y) має індекс y * 10 + x.
// Сітка - рядок зі 100 символів:
//   '.' невідомо, 'S' свій корабель, 'o' промах, 'X' влучання, '#' потоплено.

import 'dart:math';

const int boardSize = 10;
const List<int> fleet = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1];
final String emptyGrid = '.' * (boardSize * boardSize);

class Ship {
  final int x;
  final int y;
  final int length;
  final bool vertical;
  final bool sunk;

  const Ship({required this.x, required this.y, required this.length, this.vertical = false, this.sunk = false});

  factory Ship.fromJson(Map<String, dynamic> json) => Ship(
        x: (json['x'] as num).toInt(),
        y: (json['y'] as num).toInt(),
        length: (json['length'] as num).toInt(),
        vertical: json['vertical'] == true,
        sunk: json['sunk'] == true,
      );

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'length': length, 'vertical': vertical};

  List<(int, int)> get cells => [
        for (var i = 0; i < length; i++) vertical ? (x, y + i) : (x + i, y),
      ];

  bool covers(int cx, int cy) => cells.any((c) => c.$1 == cx && c.$2 == cy);
}

bool inBounds(int x, int y) => x >= 0 && y >= 0 && x < boardSize && y < boardSize;

// Чи можна поставити корабель (у межах поля й без дотику навіть кутами).
bool canPlace(List<Ship> ships, Ship ship) {
  for (final (x, y) in ship.cells) {
    if (!inBounds(x, y)) return false;
    for (final other in ships) {
      for (final (ox, oy) in other.cells) {
        if ((ox - x).abs() <= 1 && (oy - y).abs() <= 1) return false;
      }
    }
  }
  return true;
}

List<Ship> randomFleet([Random? random]) {
  final rnd = random ?? Random();
  while (true) {
    final ships = <Ship>[];
    var ok = true;
    for (final length in fleet) {
      var placed = false;
      for (var attempt = 0; attempt < 200 && !placed; attempt++) {
        final vertical = rnd.nextBool();
        final ship = Ship(
          x: rnd.nextInt(vertical ? boardSize : boardSize - length + 1),
          y: rnd.nextInt(vertical ? boardSize - length + 1 : boardSize),
          length: length,
          vertical: vertical,
        );
        if (canPlace(ships, ship)) {
          ships.add(ship);
          placed = true;
        }
      }
      if (!placed) {
        ok = false;
        break;
      }
    }
    if (ok) return ships;
  }
}

bool isSunk(Ship ship, String grid) => ship.cells.every((c) {
      final m = grid[c.$2 * boardSize + c.$1];
      return m == 'X' || m == '#';
    });

class ShotResult {
  final String grid;
  final String result; // miss | hit | sunk

  ShotResult(this.grid, this.result);
}

// null - у цю клітинку стріляти не можна.
ShotResult? applyShot(List<Ship> ships, String grid, int x, int y) {
  if (!inBounds(x, y)) return null;
  final index = y * boardSize + x;
  if (grid[index] != '.') return null;
  final cells = grid.split('');
  Ship? ship;
  for (final s in ships) {
    if (s.covers(x, y)) ship = s;
  }
  if (ship == null) {
    cells[index] = 'o';
    return ShotResult(cells.join(), 'miss');
  }
  cells[index] = 'X';
  if (!isSunk(ship, cells.join())) return ShotResult(cells.join(), 'hit');
  for (final (sx, sy) in ship.cells) {
    cells[sy * boardSize + sx] = '#';
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final nx = sx + dx;
        final ny = sy + dy;
        if (inBounds(nx, ny) && cells[ny * boardSize + nx] == '.') cells[ny * boardSize + nx] = 'o';
      }
    }
  }
  return ShotResult(cells.join(), 'sunk');
}

bool allSunk(List<Ship> ships, String grid) => ships.every((s) => isSunk(s, grid));

String ownBoard(List<Ship> ships, String grid) {
  final cells = grid.split('');
  for (final ship in ships) {
    for (final (x, y) in ship.cells) {
      if (cells[y * boardSize + x] == '.') cells[y * boardSize + x] = 'S';
    }
  }
  return cells.join();
}

String cellName(int x, int y) => '${'ABCDEFGHIJ'[x]}${y + 1}';
