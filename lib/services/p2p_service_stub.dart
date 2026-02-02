// In-memory local stub of P2PService.
// Useful for bootstrapping the app UI and state machine before radios are added.
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models.dart';
import 'p2p_service.dart';

class InMemoryP2PService implements P2PService {
  final _uuid = const Uuid();
  final _discoveredCtrl = StreamController<DiscoveredSession>.broadcast();
  final Map<String, StreamController<TokenEvent>> _tokenCtrls = {};
  final Map<String, StreamController<SessionStateEvent>> _stateCtrls = {};
  final Map<String, StreamController<ConnectionStatusEvent>> _connectionCtrls =
      {};
  final Map<String, Session> _sessions = {};

  @override
  Stream<DiscoveredSession> get discoveredSessions => _discoveredCtrl.stream;

  @override
  Future<Session> createSession({required String leaderName}) async {
    final id = _uuid.v4();
    final code = Session.shortCodeFromId(id);
    final leader = Player.named(leaderName);
    final session = Session(
      id: id,
      code: code,
      leaderId: leader.id,
      players: [leader],
      seqNo: 0,
      currentIndex: 0,
      phase: GamePhase.setup,
      playerTimes: {leader.id: Duration.zero},
    );
    _sessions[id] = session;
    _tokenCtrls[id] = StreamController<TokenEvent>.broadcast();
    _stateCtrls[id] = StreamController<SessionStateEvent>.broadcast();
    _connectionCtrls[id] = StreamController<ConnectionStatusEvent>.broadcast();

    // Simulate "advertising" by emitting on discovered stream
    _discoveredCtrl.add(DiscoveredSession(
      code: code,
      advertisedBy: leader.name,
      isInProgress: false,
    ));
    return session;
  }

  @override
  Future<void> startDiscovery() async {
    // In stub, re-emit all existing sessions
    for (final session in _sessions.values) {
      _discoveredCtrl.add(DiscoveredSession(
        code: session.code,
        advertisedBy: session.players
            .firstWhere((p) => p.id == session.leaderId)
            .name,
        isInProgress: session.phase == GamePhase.active,
      ));
    }
  }

  @override
  Future<void> stopDiscovery() async {
    // Nothing to do in stub
  }

  @override
  Future<Session> joinSession({
    required String code,
    required String playerName,
  }) async {
    final session = _sessions.values.firstWhere(
      (s) => s.code == code,
      orElse: () => throw StateError('Session with code $code not found'),
    );

    // Check if session can accept new players
    if (session.phase != GamePhase.setup) {
      throw StateError('Cannot join session that is already in progress');
    }
    if (session.isFull) {
      throw StateError('Session is full');
    }

    final newPlayer = Player.named(playerName);
    final newTimes = Map<String, Duration>.from(session.playerTimes);
    newTimes[newPlayer.id] = Duration.zero;

    final updated = session.copyWith(
      players: [...session.players, newPlayer],
      playerTimes: newTimes,
      seqNo: session.seqNo + 1,
    );
    _sessions[session.id] = updated;

    // Emit state change
    _emitSessionState(updated);

    return updated;
  }

  @override
  Future<void> startGame({required String sessionId}) async {
    final session = _sessions[sessionId];
    if (session == null) return;
    if (!session.canStart) return;

    final updated = session.copyWith(
      phase: GamePhase.active,
      currentIndex: session.startPlayerIndex,
      currentTurnStartTime: DateTime.now(),
      seqNo: session.seqNo + 1,
    );
    _sessions[sessionId] = updated;

    // Update discovery to show in-progress
    _discoveredCtrl.add(DiscoveredSession(
      code: updated.code,
      advertisedBy:
          updated.players.firstWhere((p) => p.id == updated.leaderId).name,
      isInProgress: true,
    ));

    _emitSessionState(updated);
  }

  @override
  Future<void> endGame({required String sessionId}) async {
    final session = _sessions[sessionId];
    if (session == null) return;

    final updated = session.copyWith(
      phase: GamePhase.ended,
      seqNo: session.seqNo + 1,
      clearTurnStartTime: true,
    );
    _sessions[sessionId] = updated;

    _emitSessionState(updated, finalTimes: updated.playerTimes);
  }

  @override
  Future<void> updateTimerSetting({
    required String sessionId,
    int? minutes,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) return;

    final updated = session.copyWith(
      timerMinutes: minutes,
      clearTimer: minutes == null,
      seqNo: session.seqNo + 1,
    );
    _sessions[sessionId] = updated;

    _emitSessionState(updated);
  }

  @override
  Future<void> updateStartPlayer({
    required String sessionId,
    required int startPlayerIndex,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) return;
    if (startPlayerIndex < 0 || startPlayerIndex >= session.players.length) {
      return;
    }

    final updated = session.copyWith(
      startPlayerIndex: startPlayerIndex,
      seqNo: session.seqNo + 1,
    );
    _sessions[sessionId] = updated;

    _emitSessionState(updated);
  }

  @override
  Future<void> reorderPlayers({
    required String sessionId,
    required List<String> playerIds,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) return;

    // Reorder players based on the provided order
    final reorderedPlayers = <Player>[];
    for (final id in playerIds) {
      final player = session.players.firstWhere(
        (p) => p.id == id,
        orElse: () => throw StateError('Player $id not found'),
      );
      reorderedPlayers.add(player);
    }

    // Adjust currentIndex and startPlayerIndex to maintain the same players
    final currentPlayerId = session.currentPlayer.id;
    final startPlayerId = session.startPlayer.id;
    final newCurrentIndex =
        reorderedPlayers.indexWhere((p) => p.id == currentPlayerId);
    final newStartIndex =
        reorderedPlayers.indexWhere((p) => p.id == startPlayerId);

    final updated = session.copyWith(
      players: reorderedPlayers,
      currentIndex: newCurrentIndex >= 0 ? newCurrentIndex : 0,
      startPlayerIndex: newStartIndex >= 0 ? newStartIndex : 0,
      seqNo: session.seqNo + 1,
    );
    _sessions[sessionId] = updated;

    _emitSessionState(updated);
  }

  @override
  Future<void> passTurn({
    required String sessionId,
    required String toPlayerId,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) return;

    final toIdx = session.players.indexWhere((p) => p.id == toPlayerId);
    if (toIdx < 0) return;

    final updated = session.copyWith(
      currentIndex: toIdx,
      currentTurnStartTime: DateTime.now(),
      seqNo: session.seqNo + 1,
    );
    _sessions[sessionId] = updated;

    _tokenCtrls[sessionId]?.add(TokenEvent(
      sessionId: sessionId,
      seqNo: updated.seqNo,
      fromPlayerId: session.currentPlayer.id,
      toPlayerId: updated.currentPlayer.id,
    ));
  }

  @override
  Stream<TokenEvent> onTokenChanged({required String sessionId}) {
    _tokenCtrls.putIfAbsent(
        sessionId, () => StreamController<TokenEvent>.broadcast());
    return _tokenCtrls[sessionId]!.stream;
  }

  @override
  Stream<SessionStateEvent> onSessionStateChanged({required String sessionId}) {
    _stateCtrls.putIfAbsent(
        sessionId, () => StreamController<SessionStateEvent>.broadcast());
    return _stateCtrls[sessionId]!.stream;
  }

  @override
  Stream<ConnectionStatusEvent> onConnectionStatusChanged({
    required String sessionId,
  }) {
    _connectionCtrls.putIfAbsent(
        sessionId, () => StreamController<ConnectionStatusEvent>.broadcast());
    return _connectionCtrls[sessionId]!.stream;
  }

  @override
  Future<void> leaveSession({required String sessionId}) async {
    // In a real implementation, this would notify other players
    // For stub, we just remove the session reference
  }

  @override
  Future<void> dispose() async {
    await _discoveredCtrl.close();
    for (final c in _tokenCtrls.values) {
      await c.close();
    }
    for (final c in _stateCtrls.values) {
      await c.close();
    }
    for (final c in _connectionCtrls.values) {
      await c.close();
    }
  }

  /// Helper to emit session state events
  void _emitSessionState(Session session, {Map<String, Duration>? finalTimes}) {
    _stateCtrls[session.id]?.add(SessionStateEvent(
      sessionId: session.id,
      seqNo: session.seqNo,
      phase: session.phase,
      timerMinutes: session.timerMinutes,
      players: session.players,
      currentIndex: session.currentIndex,
      startPlayerIndex: session.startPlayerIndex,
      finalTimes: finalTimes,
    ));
  }

  /// Get a session by ID (for testing/debugging)
  Session? getSession(String sessionId) => _sessions[sessionId];

  /// Update session directly (for testing/time tracking)
  void updateSession(Session session) {
    _sessions[session.id] = session;
  }
}
