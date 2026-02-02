import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Game phase states
enum GamePhase {
  /// Setup phase - players joining, leader configuring
  setup,

  /// Active phase - game in progress, no joining allowed
  active,

  /// Ended phase - game over, showing time summary
  ended,
}

/// Connection status for players
enum ConnectionStatus {
  connected,
  disconnected,
  connecting,
}

/// Represents a player in the game session
class Player {
  final String id;
  final String name;
  final ConnectionStatus connectionStatus;

  Player({
    required this.id,
    required this.name,
    this.connectionStatus = ConnectionStatus.connected,
  });

  factory Player.named(String name) => Player(
        id: _uuid.v4().substring(0, 8),
        name: name,
      );

  Player copyWith({
    String? id,
    String? name,
    ConnectionStatus? connectionStatus,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Represents a game session
class Session {
  /// Maximum players allowed in a session
  static const int maxPlayers = 8;

  /// Minimum players required to start the game
  static const int minPlayersToStart = 2;

  /// Timer range constants
  static const int minTimerMinutes = 1;
  static const int maxTimerMinutes = 15;

  final String id;
  final String code;
  final String leaderId;
  final List<Player> players;
  final int seqNo;
  final int currentIndex;
  final GamePhase phase;
  final int? timerMinutes;
  final int startPlayerIndex;
  final Map<String, Duration> playerTimes;
  final DateTime? currentTurnStartTime;

  Session({
    required this.id,
    required this.code,
    required this.leaderId,
    required this.players,
    required this.seqNo,
    required this.currentIndex,
    this.phase = GamePhase.setup,
    this.timerMinutes,
    this.startPlayerIndex = 0,
    this.playerTimes = const {},
    this.currentTurnStartTime,
  });

  /// Get the current player whose turn it is
  Player get currentPlayer => players[currentIndex];

  /// Get the designated start player
  Player get startPlayer => players[startPlayerIndex];

  /// Check if the session has enough players to start
  bool get canStart => players.length >= minPlayersToStart;

  /// Check if the session is full
  bool get isFull => players.length >= maxPlayers;

  /// Check if session is in active game phase
  bool get isActive => phase == GamePhase.active;

  /// Check if session has ended
  bool get hasEnded => phase == GamePhase.ended;

  Session copyWith({
    String? id,
    String? code,
    String? leaderId,
    List<Player>? players,
    int? seqNo,
    int? currentIndex,
    GamePhase? phase,
    int? timerMinutes,
    bool clearTimer = false,
    int? startPlayerIndex,
    Map<String, Duration>? playerTimes,
    DateTime? currentTurnStartTime,
    bool clearTurnStartTime = false,
  }) {
    return Session(
      id: id ?? this.id,
      code: code ?? this.code,
      leaderId: leaderId ?? this.leaderId,
      players: players ?? this.players,
      seqNo: seqNo ?? this.seqNo,
      currentIndex: currentIndex ?? this.currentIndex,
      phase: phase ?? this.phase,
      timerMinutes: clearTimer ? null : (timerMinutes ?? this.timerMinutes),
      startPlayerIndex: startPlayerIndex ?? this.startPlayerIndex,
      playerTimes: playerTimes ?? this.playerTimes,
      currentTurnStartTime: clearTurnStartTime
          ? null
          : (currentTurnStartTime ?? this.currentTurnStartTime),
    );
  }

  /// Generate a short human-friendly code from UUID
  static String shortCodeFromId(String id) {
    final digest = id.replaceAll('-', '');
    return '${digest.substring(0, 3).toUpperCase()}-${digest.substring(3, 4)}';
  }
}
