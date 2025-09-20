import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Player {
  final String id; // stable per-session
  final String name;

  Player({required this.id, required this.name});

  factory Player.named(String name) => Player(id: _uuid.v4().substring(0, 8), name: name);
}

class Session {
  final String id; // full UUID
  final String code; // short human code (e.g., "J7X-3")
  final String leaderId;
  final List<Player> players;
  final int seqNo; // monotonic for state changes
  final int currentIndex; // who holds the token

  Session({
    required this.id,
    required this.code,
    required this.leaderId,
    required this.players,
    required this.seqNo,
    required this.currentIndex,
  });

  Player get currentPlayer => players[currentIndex];

  Session copyWith({
    String? id,
    String? code,
    String? leaderId,
    List<Player>? players,
    int? seqNo,
    int? currentIndex,
  }) {
    return Session(
      id: id ?? this.id,
      code: code ?? this.code,
      leaderId: leaderId ?? this.leaderId,
      players: players ?? this.players,
      seqNo: seqNo ?? this.seqNo,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }

  static String shortCodeFromId(String id) {
    // tiny, human-friendly code derived from UUID
    // Not cryptographically secure; just a join hint for friends at the table.
    final digest = id.replaceAll('-', '');
    return "${digest.substring(0, 3).toUpperCase()}-${digest.substring(3, 4)}";
  }
}
