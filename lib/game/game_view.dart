// Стан гри з погляду гравця - формат об'єкта `game` з API сервера.
// Офлайн-гра з ботом будує такий самий об'єкт, тож екрани спільні.

import 'rules.dart';

class LastShot {
  final bool byMe;
  final int x;
  final int y;
  final String result; // miss | hit | sunk

  const LastShot({required this.byMe, required this.x, required this.y, required this.result});

  factory LastShot.fromJson(Map<String, dynamic> json) => LastShot(
        byMe: json['by'] == 'you',
        x: (json['x'] as num).toInt(),
        y: (json['y'] as num).toInt(),
        result: json['result'] as String,
      );

  bool sameAs(LastShot? other) =>
      other != null && other.byMe == byMe && other.x == x && other.y == y && other.result == result;
}

class PlayerSide {
  final String nickname;
  final bool ready;
  final String board;
  final List<Ship> ships; // свої: всі кораблі; суперника: лише потоплені

  const PlayerSide({required this.nickname, required this.ready, required this.board, required this.ships});
}

class GameView {
  final String id;
  final String status; // waiting | placing | playing | finished | cancelled
  final bool isPrivate;
  final String? code;
  final PlayerSide you;
  final PlayerSide? opponent;
  final bool yourTurn;
  final int? timeLeftMs;
  final DateTime receivedAt;
  final LastShot? lastShot;
  final String? winner; // you | opponent
  final String? reason; // all_sunk | surrender | timeout | left
  final bool local;

  GameView({
    required this.id,
    required this.status,
    required this.isPrivate,
    required this.code,
    required this.you,
    required this.opponent,
    required this.yourTurn,
    required this.timeLeftMs,
    required this.lastShot,
    required this.winner,
    required this.reason,
    this.local = false,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  bool get active => status == 'waiting' || status == 'placing' || status == 'playing';

  Duration? get timeLeft {
    if (timeLeftMs == null) return null;
    final left = timeLeftMs! - DateTime.now().difference(receivedAt).inMilliseconds;
    return Duration(milliseconds: left < 0 ? 0 : left);
  }

  factory GameView.fromJson(Map<String, dynamic> json) {
    final you = json['you'] as Map<String, dynamic>;
    final op = json['opponent'] as Map<String, dynamic>?;
    final shot = json['lastShot'] as Map<String, dynamic>?;
    return GameView(
      id: json['id'] as String,
      status: json['status'] as String,
      isPrivate: json['private'] == true,
      code: json['code'] as String?,
      you: PlayerSide(
        nickname: you['nickname'] as String? ?? '?',
        ready: you['ready'] == true,
        board: you['board'] as String,
        ships: ((you['ships'] as List?) ?? []).map((s) => Ship.fromJson(s as Map<String, dynamic>)).toList(),
      ),
      opponent: op == null
          ? null
          : PlayerSide(
              nickname: op['nickname'] as String? ?? '?',
              ready: op['ready'] == true,
              board: op['board'] as String,
              ships: ((op['sunkShips'] as List?) ?? [])
                  .map((s) => Ship.fromJson({...(s as Map<String, dynamic>), 'sunk': true}))
                  .toList(),
            ),
      yourTurn: json['yourTurn'] == true,
      timeLeftMs: (json['timeLeftMs'] as num?)?.toInt(),
      lastShot: shot == null ? null : LastShot.fromJson(shot),
      winner: json['winner'] as String?,
      reason: json['reason'] as String?,
    );
  }
}
