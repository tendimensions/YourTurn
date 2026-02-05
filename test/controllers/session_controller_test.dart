import 'package:flutter_test/flutter_test.dart';
import 'package:yourturn/controllers/session_controller.dart';
import 'package:yourturn/models.dart';
import 'package:yourturn/services/p2p_service_stub.dart';
import 'package:yourturn/services/screen_service.dart';

void main() {
  late SessionController controller;
  late InMemoryP2PService p2pService;
  late ScreenServiceStub screenService;

  setUp(() {
    p2pService = InMemoryP2PService();
    screenService = ScreenServiceStub();
    controller = SessionController(
      p2p: p2pService,
      screenService: screenService,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('SessionController initial state', () {
    test('has null session initially', () {
      expect(controller.session, isNull);
    });

    test('has null myPlayerId initially', () {
      expect(controller.myPlayerId, isNull);
    });

    test('has empty players list initially', () {
      expect(controller.players, isEmpty);
    });

    test('has null currentPlayer initially', () {
      expect(controller.currentPlayer, isNull);
    });

    test('is not leader initially', () {
      expect(controller.isLeader, isFalse);
    });

    test('is not my turn initially', () {
      expect(controller.isMyTurn, isFalse);
    });

    test('has setup phase initially', () {
      expect(controller.phase, GamePhase.setup);
    });

    test('cannot start game initially', () {
      expect(controller.canStartGame, isFalse);
    });
  });

  group('SessionController.createSession', () {
    test('creates session with leader name', () async {
      await controller.createSession('Alice');

      expect(controller.session, isNotNull);
      expect(controller.session!.players.first.name, 'Alice');
    });

    test('sets myPlayerId to leader id', () async {
      await controller.createSession('Alice');

      expect(controller.myPlayerId, isNotNull);
      expect(controller.myPlayerId, controller.session!.leaderId);
    });

    test('sets isLeader to true', () async {
      await controller.createSession('Alice');

      expect(controller.isLeader, isTrue);
    });

    test('session starts in setup phase', () async {
      await controller.createSession('Alice');

      expect(controller.phase, GamePhase.setup);
    });

    test('session has one player (the leader)', () async {
      await controller.createSession('Alice');

      expect(controller.players.length, 1);
    });

    test('notifies listeners after creating session', () async {
      var notified = false;
      controller.addListener(() => notified = true);

      await controller.createSession('Alice');

      expect(notified, isTrue);
    });
  });

  group('SessionController.joinSession', () {
    test('joins existing session by code', () async {
      // Create a session first
      await controller.createSession('Alice');
      final code = controller.session!.code;

      // Create a new controller to join
      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      expect(joiner.session, isNotNull);
      expect(joiner.players.length, 2);

      joiner.dispose();
    });

    test('joining player is not leader', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      expect(joiner.isLeader, isFalse);

      joiner.dispose();
    });

    test('sets myPlayerId to joined player id', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      expect(joiner.myPlayerId, isNotNull);
      expect(joiner.myPlayerId, isNot(equals(controller.myPlayerId)));

      joiner.dispose();
    });
  });

  group('SessionController.canStartGame', () {
    test('returns false with only one player', () async {
      await controller.createSession('Alice');

      expect(controller.canStartGame, isFalse);
    });

    test('returns true with two players when leader', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      expect(controller.canStartGame, isTrue);

      joiner.dispose();
    });

    test('returns false for non-leader', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      expect(joiner.canStartGame, isFalse);

      joiner.dispose();
    });
  });

  group('SessionController.canJoinSession', () {
    test('returns true in setup phase when not full', () async {
      await controller.createSession('Alice');

      expect(controller.canJoinSession, isTrue);
    });
  });

  group('SessionController.startGame', () {
    test('transitions to active phase', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.startGame();

      expect(controller.phase, GamePhase.active);

      joiner.dispose();
    });

    test('does nothing if not leader', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await joiner.startGame(); // Joiner tries to start

      expect(controller.phase, GamePhase.setup);

      joiner.dispose();
    });

    test('does nothing with insufficient players', () async {
      await controller.createSession('Alice');

      await controller.startGame();

      expect(controller.phase, GamePhase.setup);
    });

    test('enables wake lock on start', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.startGame();

      expect(screenService.wakeLockEnabled, isTrue);

      joiner.dispose();
    });

    test('sets currentIndex to startPlayerIndex', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      controller.setStartPlayer(1); // Set Bob as start player
      await controller.startGame();

      expect(controller.session!.currentIndex, 1);

      joiner.dispose();
    });
  });

  group('SessionController.endGame', () {
    test('transitions to ended phase', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.startGame();
      await controller.endGame();

      expect(controller.phase, GamePhase.ended);

      joiner.dispose();
    });

    test('does nothing if not leader', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.startGame();
      await joiner.endGame(); // Joiner tries to end

      expect(controller.phase, GamePhase.active);

      joiner.dispose();
    });

    test('disables wake lock on end', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.startGame();
      expect(screenService.wakeLockEnabled, isTrue);

      await controller.endGame();
      expect(screenService.wakeLockEnabled, isFalse);

      joiner.dispose();
    });
  });

  group('SessionController.isMyTurn', () {
    test('returns true when it is my turn in active game', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.startGame();

      expect(controller.isMyTurn, isTrue);
      expect(joiner.isMyTurn, isFalse);

      joiner.dispose();
    });

    test('returns false in setup phase', () async {
      await controller.createSession('Alice');

      expect(controller.isMyTurn, isFalse);
    });
  });

  group('SessionController.passTurnToNext', () {
    test('advances to next player', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.startGame();
      expect(controller.session!.currentIndex, 0);

      await controller.passTurnToNext();

      expect(controller.session!.currentIndex, 1);

      joiner.dispose();
    });

    test('wraps around to first player', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.startGame();
      await controller.passTurnToNext(); // Now Bob's turn (index 1)
      await controller.passTurnToNext(); // Should wrap to Alice (index 0)

      expect(controller.session!.currentIndex, 0);

      joiner.dispose();
    });

    test('does nothing in setup phase', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.passTurnToNext();

      expect(controller.session!.currentIndex, 0);

      joiner.dispose();
    });

    test('increments seqNo', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.startGame();
      await Future.delayed(const Duration(milliseconds: 10)); // Allow stream events to process
      final seqNoBefore = controller.session!.seqNo;

      await controller.passTurnToNext();
      await Future.delayed(const Duration(milliseconds: 10)); // Allow stream events to process

      expect(controller.session!.seqNo, greaterThan(seqNoBefore));

      joiner.dispose();
    });
  });

  group('SessionController.reorderPlayers', () {
    test('reorders players in the list', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      final joiner2 = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner2.joinSession(code, 'Charlie');

      expect(controller.players[0].name, 'Alice');
      expect(controller.players[1].name, 'Bob');
      expect(controller.players[2].name, 'Charlie');

      controller.reorderPlayers(0, 3); // Move Alice to end

      expect(controller.players[0].name, 'Bob');
      expect(controller.players[1].name, 'Charlie');
      expect(controller.players[2].name, 'Alice');

      joiner.dispose();
      joiner2.dispose();
    });

    test('adjusts startPlayerIndex after reorder', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      controller.setStartPlayer(0); // Alice is start player
      final aliceId = controller.players[0].id;

      controller.reorderPlayers(0, 2); // Move Alice to end

      // Start player should still be Alice (now at index 1)
      expect(controller.startPlayer!.id, aliceId);

      joiner.dispose();
    });

    test('does nothing if not leader', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      joiner.reorderPlayers(0, 2);

      // Order should be unchanged
      expect(controller.players[0].name, 'Alice');

      joiner.dispose();
    });
  });

  group('SessionController.setStartPlayer', () {
    test('sets start player index', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      controller.setStartPlayer(1);

      expect(controller.startPlayerIndex, 1);
      expect(controller.startPlayer!.name, 'Bob');

      joiner.dispose();
    });

    test('does nothing with invalid index (negative)', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      controller.setStartPlayer(-1);

      expect(controller.startPlayerIndex, 0);

      joiner.dispose();
    });

    test('does nothing with invalid index (too large)', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      controller.setStartPlayer(10);

      expect(controller.startPlayerIndex, 0);

      joiner.dispose();
    });

    test('does nothing if not leader', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      joiner.setStartPlayer(1);

      expect(controller.startPlayerIndex, 0);

      joiner.dispose();
    });
  });

  group('SessionController.setTimerMinutes', () {
    test('sets timer minutes', () async {
      await controller.createSession('Alice');

      await controller.setTimerMinutes(5);

      expect(controller.timerMinutes, 5);
    });

    test('clears timer with null', () async {
      await controller.createSession('Alice');
      await controller.setTimerMinutes(5);

      await controller.setTimerMinutes(null);

      expect(controller.timerMinutes, isNull);
    });

    test('rejects value below minimum', () async {
      await controller.createSession('Alice');

      await controller.setTimerMinutes(0);

      expect(controller.timerMinutes, isNull);
    });

    test('rejects value above maximum', () async {
      await controller.createSession('Alice');

      await controller.setTimerMinutes(20);

      expect(controller.timerMinutes, isNull);
    });

    test('accepts minimum value', () async {
      await controller.createSession('Alice');

      await controller.setTimerMinutes(Session.minTimerMinutes);

      expect(controller.timerMinutes, Session.minTimerMinutes);
    });

    test('accepts maximum value', () async {
      await controller.createSession('Alice');

      await controller.setTimerMinutes(Session.maxTimerMinutes);

      expect(controller.timerMinutes, Session.maxTimerMinutes);
    });

    test('does nothing if not leader', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await joiner.setTimerMinutes(5);

      expect(controller.timerMinutes, isNull);

      joiner.dispose();
    });
  });

  group('SessionController.leaveSession', () {
    test('clears session and myPlayerId', () async {
      await controller.createSession('Alice');

      await controller.leaveSession();

      expect(controller.session, isNull);
      expect(controller.myPlayerId, isNull);
    });

    test('disables wake lock', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.startGame();
      expect(screenService.wakeLockEnabled, isTrue);

      await controller.leaveSession();
      expect(screenService.wakeLockEnabled, isFalse);

      joiner.dispose();
    });

    test('does nothing if no session', () async {
      await controller.leaveSession();

      expect(controller.session, isNull);
    });
  });

  group('SessionController.returnToLobby', () {
    test('clears session state', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.startGame();
      await controller.endGame();

      controller.returnToLobby();

      expect(controller.session, isNull);
      expect(controller.myPlayerId, isNull);

      joiner.dispose();
    });
  });

  group('SessionController.getPlayerTime', () {
    test('returns zero for unknown player', () async {
      await controller.createSession('Alice');

      expect(controller.getPlayerTime('unknown-id'), Duration.zero);
    });
  });

  group('SessionController notifies listeners', () {
    test('notifies on createSession', () async {
      var notified = false;
      controller.addListener(() => notified = true);

      await controller.createSession('Alice');

      expect(notified, isTrue);
    });

    test('notifies on startGame', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      var notified = false;
      controller.addListener(() => notified = true);

      await controller.startGame();

      expect(notified, isTrue);

      joiner.dispose();
    });

    test('notifies on passTurnToNext', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      await controller.startGame();

      var notified = false;
      controller.addListener(() => notified = true);

      await controller.passTurnToNext();

      expect(notified, isTrue);

      joiner.dispose();
    });

    test('notifies on setTimerMinutes', () async {
      await controller.createSession('Alice');

      var notified = false;
      controller.addListener(() => notified = true);

      await controller.setTimerMinutes(5);

      expect(notified, isTrue);
    });

    test('notifies on setStartPlayer', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      var notified = false;
      controller.addListener(() => notified = true);

      controller.setStartPlayer(1);

      expect(notified, isTrue);

      joiner.dispose();
    });

    test('notifies on reorderPlayers', () async {
      await controller.createSession('Alice');
      final code = controller.session!.code;

      final joiner = SessionController(
        p2p: p2pService,
        screenService: ScreenServiceStub(),
      );
      await joiner.joinSession(code, 'Bob');

      var notified = false;
      controller.addListener(() => notified = true);

      controller.reorderPlayers(0, 2);

      expect(notified, isTrue);

      joiner.dispose();
    });

    test('notifies on leaveSession', () async {
      await controller.createSession('Alice');

      var notified = false;
      controller.addListener(() => notified = true);

      await controller.leaveSession();

      expect(notified, isTrue);
    });

    test('notifies on returnToLobby', () async {
      await controller.createSession('Alice');

      var notified = false;
      controller.addListener(() => notified = true);

      controller.returnToLobby();

      expect(notified, isTrue);
    });
  });
}
