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
    );
    _sessions[id] = session;
    _tokenCtrls[id] = StreamController<TokenEvent>.broadcast();
    // Simulate "advertising" by emitting on discovered stream
    _discoveredCtrl.add(DiscoveredSession(code: code, advertisedBy: leader.name));
    return session;
  }

  @override
  Future<void> startDiscovery() async {
    // Nothing to do in stub; real impl would start BLE/MC/NC scan here.
  }

  @override
  Future<Session> joinSession({required String code, required String playerName}) async {
    final session = _sessions.values.firstWhere(
      (s) => s.code == code,
      orElse: () => throw StateError('Session with code $code not found'),
    );
    final newPlayer = Player.named(playerName);
    final updated = session.copyWith(
      players: [...session.players, newPlayer],
      seqNo: session.seqNo + 1,
    );
    _sessions[session.id] = updated;
    return updated;
  }

  @override
  Future<void> passTurn({required String sessionId, required String toPlayerId}) async {
    final session = _sessions[sessionId];
    if (session == null) return;
    final toIdx = session.players.indexWhere((p) => p.id == toPlayerId);
    if (toIdx < 0) return;
    final updated = session.copyWith(
      currentIndex: toIdx,
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
    _tokenCtrls.putIfAbsent(sessionId, () => StreamController<TokenEvent>.broadcast());
    return _tokenCtrls[sessionId]!.stream;
  }

  @override
  Future<void> dispose() async {
    await _discoveredCtrl.close();
    for (final c in _tokenCtrls.values) {
      await c.close();
    }
  }
}
