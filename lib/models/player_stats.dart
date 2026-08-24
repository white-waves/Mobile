class PlayerStats {
  final String id;
  final String nickname;
  final String country;
  final int battles;
  final int wins;
  final int shipsDestroyed;
  final int points;

  PlayerStats({
    required this.id,
    required this.nickname,
    required this.country,
    required this.battles,
    required this.wins,
    required this.shipsDestroyed,
    required this.points,
  });

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>;
    return PlayerStats(
      id: json['id'].toString(),
      nickname: json['nickname'] as String,
      country: json['country'] as String,
      battles: stats['battles'] as int,
      wins: stats['wins'] as int,
      shipsDestroyed: stats['shipsDestroyed'] as int,
      points: stats['points'] as int,
    );
  }
}
