class Lobby {
  final String id;
  final List<String> nicknames;
  final String status; // 'waiting' | 'matched' | 'in_progress'
  final List<String> readyPlayers;

  Lobby({
    required this.id,
    required this.nicknames,
    required this.status,
    required this.readyPlayers,
  });

  bool get inProgress => status == 'in_progress';

  factory Lobby.fromJson(Map<String, dynamic> json) {
    return Lobby(
      id: json['_id'] as String,
      nicknames: (json['nicknames'] as List).cast<String>(),
      status: json['status'] as String,
      readyPlayers: (json['readyPlayers'] as List).cast<String>(),
    );
  }
}

class FindGameResult {
  final bool matchFound;
  final Lobby lobby;

  FindGameResult({required this.matchFound, required this.lobby});

  factory FindGameResult.fromJson(Map<String, dynamic> json) {
    return FindGameResult(
      matchFound: json['status'] == 'match_found',
      lobby: Lobby.fromJson(json['lobby'] as Map<String, dynamic>),
    );
  }
}
