import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/p2p_service.dart';
import '../services/p2p_service_stub.dart';

class SessionController extends ChangeNotifier {
  final P2PService _p2p;
  Session? _session;
  StreamSubscription? _tokenSub;

  Session? get session => _session;
  bool get isLeader => _session != null && _session!.leaderId == _myPlayerId;
  String? _myPlayerId;

  SessionController({P2PService? p2p}) : _p2p = p2p ?? InMemoryP2PService();

  List<Player> get players => _session?.players ?? const [];
  Player? get currentPlayer => _session?.currentPlayer;

  Future<void> createSession(String leaderName) async {
    final s = await _p2p.createSession(leaderName: leaderName);
    _session = s;
    _myPlayerId = s.leaderId;
    _listenToken();
    notifyListeners();
  }

  Future<void> startDiscovery() async {
    await _p2p.startDiscovery();
  }

  Future<void> joinSession(String code, String playerName) async {
    final s = await _p2p.joinSession(code: code, playerName: playerName);
    _session = s;
    // In a real P2P join, you'd capture the assigned playerId from the host.
    // Here we simply remember the last-joined player's ID (best effort in stub).
    _myPlayerId = s.players.last.id;
    _listenToken();
    notifyListeners();
  }

  void reorderPlayers(int oldIndex, int newIndex) {
    if (_session == null || !isLeader) return;
    final list = [..._session!.players];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _session = _session!.copyWith(players: list, seqNo: _session!.seqNo + 1);
    notifyListeners();
  }

  Future<void> passTurnToNext() async {
    if (_session == null) return;
    final nextIdx = (_session!.currentIndex + 1) % _session!.players.length;
    final next = _session!.players[nextIdx];
    await _p2p.passTurn(sessionId: _session!.id, toPlayerId: next.id);
  }

  void _listenToken() {
    _tokenSub?.cancel();
    final s = _session;
    if (s == null) return;
    _tokenSub = _p2p.onTokenChanged(sessionId: s.id).listen((evt) {
      if (_session == null || _session!.id != evt.sessionId) return;
      final toIdx = _session!.players.indexWhere((p) => p.id == evt.toPlayerId);
      if (toIdx >= 0) {
        _session = _session!.copyWith(currentIndex: toIdx, seqNo: evt.seqNo);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    _p2p.dispose();
    super.dispose();
  }
}
