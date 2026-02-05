import 'package:flutter_test/flutter_test.dart';
import 'package:yourturn/models.dart';

import 'fixtures/test_data.dart';

void main() {
  group('GamePhase', () {
    test('has all expected values', () {
      expect(GamePhase.values, contains(GamePhase.setup));
      expect(GamePhase.values, contains(GamePhase.active));
      expect(GamePhase.values, contains(GamePhase.ended));
      expect(GamePhase.values.length, 3);
    });
  });

  group('ConnectionStatus', () {
    test('has all expected values', () {
      expect(ConnectionStatus.values, contains(ConnectionStatus.connected));
      expect(ConnectionStatus.values, contains(ConnectionStatus.disconnected));
      expect(ConnectionStatus.values, contains(ConnectionStatus.connecting));
      expect(ConnectionStatus.values.length, 3);
    });
  });

  group('Player', () {
    test('creates player with required fields', () {
      final player = Player(
        id: '123',
        name: 'Alice',
      );

      expect(player.id, '123');
      expect(player.name, 'Alice');
      expect(player.connectionStatus, ConnectionStatus.connected);
    });

    test('creates player with custom connection status', () {
      final player = Player(
        id: '123',
        name: 'Alice',
        connectionStatus: ConnectionStatus.disconnected,
      );

      expect(player.connectionStatus, ConnectionStatus.disconnected);
    });

    test('Player.named factory creates player with generated id', () {
      final player = Player.named('Bob');

      expect(player.name, 'Bob');
      expect(player.id, isNotEmpty);
      expect(player.id.length, 8);
      expect(player.connectionStatus, ConnectionStatus.connected);
    });

    test('Player.named generates unique ids', () {
      final player1 = Player.named('Alice');
      final player2 = Player.named('Bob');

      expect(player1.id, isNot(equals(player2.id)));
    });

    test('copyWith creates new player with updated fields', () {
      final player = TestPlayers.alice();
      final updated = player.copyWith(name: 'Alice Updated');

      expect(updated.id, player.id);
      expect(updated.name, 'Alice Updated');
      expect(updated.connectionStatus, player.connectionStatus);
    });

    test('copyWith can update connection status', () {
      final player = TestPlayers.alice();
      final updated = player.copyWith(
        connectionStatus: ConnectionStatus.disconnected,
      );

      expect(updated.connectionStatus, ConnectionStatus.disconnected);
      expect(updated.name, player.name);
    });

    test('copyWith preserves all fields when no updates provided', () {
      final player = TestPlayers.alice();
      final copy = player.copyWith();

      expect(copy.id, player.id);
      expect(copy.name, player.name);
      expect(copy.connectionStatus, player.connectionStatus);
    });

    test('equality is based on id only', () {
      final player1 = Player(id: '123', name: 'Alice');
      final player2 = Player(id: '123', name: 'Different Name');
      final player3 = Player(id: '456', name: 'Alice');

      expect(player1, equals(player2));
      expect(player1, isNot(equals(player3)));
    });

    test('hashCode is based on id', () {
      final player1 = Player(id: '123', name: 'Alice');
      final player2 = Player(id: '123', name: 'Bob');

      expect(player1.hashCode, equals(player2.hashCode));
    });
  });

  group('Session', () {
    test('creates session with required fields', () {
      final session = TestSessions.basic();

      expect(session.id, 'session-123');
      expect(session.code, 'ABC-1');
      expect(session.leaderId, 'alice-id');
      expect(session.players.length, 2);
      expect(session.seqNo, 0);
      expect(session.currentIndex, 0);
      expect(session.phase, GamePhase.setup);
    });

    test('has correct default values', () {
      final session = Session(
        id: 'test',
        code: 'TST-1',
        leaderId: 'leader',
        players: [],
        seqNo: 0,
        currentIndex: 0,
      );

      expect(session.phase, GamePhase.setup);
      expect(session.timerMinutes, isNull);
      expect(session.startPlayerIndex, 0);
      expect(session.playerTimes, isEmpty);
      expect(session.currentTurnStartTime, isNull);
    });

    group('constants', () {
      test('maxPlayers is 8', () {
        expect(Session.maxPlayers, 8);
      });

      test('minPlayersToStart is 2', () {
        expect(Session.minPlayersToStart, 2);
      });

      test('minTimerMinutes is 1', () {
        expect(Session.minTimerMinutes, 1);
      });

      test('maxTimerMinutes is 15', () {
        expect(Session.maxTimerMinutes, 15);
      });
    });

    group('currentPlayer', () {
      test('returns player at currentIndex', () {
        final session = TestSessions.basic();

        expect(session.currentPlayer, TestPlayers.alice());
      });

      test('returns correct player when currentIndex changes', () {
        final session = TestSessions.basic().copyWith(currentIndex: 1);

        expect(session.currentPlayer.name, 'Bob');
      });
    });

    group('startPlayer', () {
      test('returns player at startPlayerIndex', () {
        final session = TestSessions.basic();

        expect(session.startPlayer, TestPlayers.alice());
      });

      test('returns correct player when startPlayerIndex is set', () {
        final session = TestSessions.basic().copyWith(startPlayerIndex: 1);

        expect(session.startPlayer.name, 'Bob');
      });
    });

    group('canStart', () {
      test('returns true when player count meets minimum', () {
        final session = TestSessions.basic();

        expect(session.canStart, isTrue);
      });

      test('returns false when player count is below minimum', () {
        final session = TestSessions.singlePlayer();

        expect(session.canStart, isFalse);
      });

      test('returns true with exactly minPlayersToStart', () {
        final session = TestSessions.basic();

        expect(session.players.length, Session.minPlayersToStart);
        expect(session.canStart, isTrue);
      });
    });

    group('isFull', () {
      test('returns false when session has room', () {
        final session = TestSessions.basic();

        expect(session.isFull, isFalse);
      });

      test('returns true when session is at max capacity', () {
        final session = TestSessions.fullSession();

        expect(session.players.length, Session.maxPlayers);
        expect(session.isFull, isTrue);
      });
    });

    group('isActive', () {
      test('returns false in setup phase', () {
        final session = TestSessions.basic();

        expect(session.isActive, isFalse);
      });

      test('returns true in active phase', () {
        final session = TestSessions.activeGame();

        expect(session.isActive, isTrue);
      });

      test('returns false in ended phase', () {
        final session = TestSessions.endedGame();

        expect(session.isActive, isFalse);
      });
    });

    group('hasEnded', () {
      test('returns false in setup phase', () {
        final session = TestSessions.basic();

        expect(session.hasEnded, isFalse);
      });

      test('returns false in active phase', () {
        final session = TestSessions.activeGame();

        expect(session.hasEnded, isFalse);
      });

      test('returns true in ended phase', () {
        final session = TestSessions.endedGame();

        expect(session.hasEnded, isTrue);
      });
    });

    group('copyWith', () {
      test('creates copy with updated phase', () {
        final session = TestSessions.basic();
        final updated = session.copyWith(phase: GamePhase.active);

        expect(updated.phase, GamePhase.active);
        expect(updated.id, session.id);
      });

      test('creates copy with updated timerMinutes', () {
        final session = TestSessions.basic();
        final updated = session.copyWith(timerMinutes: 5);

        expect(updated.timerMinutes, 5);
      });

      test('clearTimer removes timer setting', () {
        final session = TestSessions.withTimer();
        expect(session.timerMinutes, 5);

        final updated = session.copyWith(clearTimer: true);

        expect(updated.timerMinutes, isNull);
      });

      test('creates copy with updated players list', () {
        final session = TestSessions.basic();
        final newPlayers = [TestPlayers.alice()];
        final updated = session.copyWith(players: newPlayers);

        expect(updated.players.length, 1);
      });

      test('creates copy with updated currentIndex', () {
        final session = TestSessions.basic();
        final updated = session.copyWith(currentIndex: 1);

        expect(updated.currentIndex, 1);
      });

      test('creates copy with updated seqNo', () {
        final session = TestSessions.basic();
        final updated = session.copyWith(seqNo: 42);

        expect(updated.seqNo, 42);
      });

      test('creates copy with updated playerTimes', () {
        final session = TestSessions.basic();
        final times = {'alice-id': const Duration(minutes: 5)};
        final updated = session.copyWith(playerTimes: times);

        expect(updated.playerTimes['alice-id'], const Duration(minutes: 5));
      });

      test('creates copy with currentTurnStartTime', () {
        final session = TestSessions.basic();
        final now = DateTime.now();
        final updated = session.copyWith(currentTurnStartTime: now);

        expect(updated.currentTurnStartTime, now);
      });

      test('clearTurnStartTime removes turn start time', () {
        final session = TestSessions.activeGame();
        expect(session.currentTurnStartTime, isNotNull);

        final updated = session.copyWith(clearTurnStartTime: true);

        expect(updated.currentTurnStartTime, isNull);
      });

      test('preserves all fields when no updates provided', () {
        final session = TestSessions.withTimer();
        final copy = session.copyWith();

        expect(copy.id, session.id);
        expect(copy.code, session.code);
        expect(copy.leaderId, session.leaderId);
        expect(copy.players.length, session.players.length);
        expect(copy.seqNo, session.seqNo);
        expect(copy.currentIndex, session.currentIndex);
        expect(copy.phase, session.phase);
        expect(copy.timerMinutes, session.timerMinutes);
        expect(copy.startPlayerIndex, session.startPlayerIndex);
      });
    });

    group('shortCodeFromId', () {
      test('generates code in XXX-X format', () {
        final code = Session.shortCodeFromId('abcdefgh-1234-5678-90ab-cdef12345678');

        expect(code, matches(RegExp(r'^[A-Z0-9]{3}-[A-Z0-9]$')));
      });

      test('converts to uppercase', () {
        final code = Session.shortCodeFromId('abcdefgh-1234-5678-90ab-cdef12345678');

        expect(code, equals(code.toUpperCase()));
      });

      test('produces consistent output for same input', () {
        const id = 'test-uuid-1234-5678';
        final code1 = Session.shortCodeFromId(id);
        final code2 = Session.shortCodeFromId(id);

        expect(code1, equals(code2));
      });

      test('produces different output for different inputs', () {
        final code1 = Session.shortCodeFromId('uuid-1111-aaaa-bbbb');
        final code2 = Session.shortCodeFromId('uuid-2222-cccc-dddd');

        expect(code1, isNot(equals(code2)));
      });
    });
  });
}
