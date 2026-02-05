import 'package:yourturn/models.dart';

/// Reusable test data for YourTurn tests.
/// Following the testing guidelines for test fixtures.
class TestPlayers {
  static Player alice() => Player(
        id: 'alice-id',
        name: 'Alice',
        connectionStatus: ConnectionStatus.connected,
      );

  static Player bob() => Player(
        id: 'bob-id',
        name: 'Bob',
        connectionStatus: ConnectionStatus.connected,
      );

  static Player charlie() => Player(
        id: 'charlie-id',
        name: 'Charlie',
        connectionStatus: ConnectionStatus.connected,
      );

  static Player disconnectedPlayer() => Player(
        id: 'disconnected-id',
        name: 'Disconnected',
        connectionStatus: ConnectionStatus.disconnected,
      );

  static Player connectingPlayer() => Player(
        id: 'connecting-id',
        name: 'Connecting',
        connectionStatus: ConnectionStatus.connecting,
      );

  static List<Player> defaultPlayers() => [alice(), bob()];

  static List<Player> threePlayers() => [alice(), bob(), charlie()];
}

class TestSessions {
  static Session basic() => Session(
        id: 'session-123',
        code: 'ABC-1',
        leaderId: 'alice-id',
        players: TestPlayers.defaultPlayers(),
        seqNo: 0,
        currentIndex: 0,
        phase: GamePhase.setup,
      );

  static Session withThreePlayers() => Session(
        id: 'session-456',
        code: 'DEF-2',
        leaderId: 'alice-id',
        players: TestPlayers.threePlayers(),
        seqNo: 0,
        currentIndex: 0,
        phase: GamePhase.setup,
      );

  static Session activeGame() => Session(
        id: 'session-789',
        code: 'GHI-3',
        leaderId: 'alice-id',
        players: TestPlayers.defaultPlayers(),
        seqNo: 1,
        currentIndex: 0,
        phase: GamePhase.active,
        currentTurnStartTime: DateTime.now(),
      );

  static Session endedGame() => Session(
        id: 'session-ended',
        code: 'JKL-4',
        leaderId: 'alice-id',
        players: TestPlayers.defaultPlayers(),
        seqNo: 2,
        currentIndex: 0,
        phase: GamePhase.ended,
        playerTimes: {
          'alice-id': const Duration(minutes: 5, seconds: 30),
          'bob-id': const Duration(minutes: 4, seconds: 15),
        },
      );

  static Session withTimer() => Session(
        id: 'session-timer',
        code: 'MNO-5',
        leaderId: 'alice-id',
        players: TestPlayers.defaultPlayers(),
        seqNo: 0,
        currentIndex: 0,
        phase: GamePhase.setup,
        timerMinutes: 5,
      );

  static Session singlePlayer() => Session(
        id: 'session-single',
        code: 'PQR-6',
        leaderId: 'alice-id',
        players: [TestPlayers.alice()],
        seqNo: 0,
        currentIndex: 0,
        phase: GamePhase.setup,
      );

  static Session fullSession() {
    final players = <Player>[];
    for (var i = 0; i < Session.maxPlayers; i++) {
      players.add(Player(
        id: 'player-$i',
        name: 'Player $i',
        connectionStatus: ConnectionStatus.connected,
      ));
    }
    return Session(
      id: 'session-full',
      code: 'STU-7',
      leaderId: 'player-0',
      players: players,
      seqNo: 0,
      currentIndex: 0,
      phase: GamePhase.setup,
    );
  }
}
