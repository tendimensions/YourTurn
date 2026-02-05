import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/p2p_service.dart';
import '../services/p2p_service_factory.dart';
import '../services/screen_service.dart';

/// Controller for managing game session state.
/// Handles game phases, time tracking, timer settings, and turn management.
class SessionController extends ChangeNotifier {
  final P2PService _p2p;
  final ScreenService _screenService;
  Session? _session;
  String? _myPlayerId;

  StreamSubscription? _tokenSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _connectionSub;

  SessionController({
    P2PService? p2p,
    ScreenService? screenService,
  })  : _p2p = p2p ?? createP2PService(),
        _screenService = screenService ?? ScreenServiceStub();

  // === Basic Getters ===

  Session? get session => _session;
  String? get myPlayerId => _myPlayerId;
  List<Player> get players => _session?.players ?? const [];
  Player? get currentPlayer =>
      _session != null && _session!.players.isNotEmpty
          ? _session!.currentPlayer
          : null;

  // === Role Checks ===

  bool get isLeader =>
      _session != null && _session!.leaderId == _myPlayerId;

  bool get isMyTurn =>
      _session != null &&
      phase == GamePhase.active &&
      currentPlayer?.id == _myPlayerId;

  // === Game Phase ===

  GamePhase get phase => _session?.phase ?? GamePhase.setup;

  bool get canStartGame =>
      isLeader && _session?.canStart == true && phase == GamePhase.setup;

  bool get canJoinSession =>
      phase == GamePhase.setup && _session?.isFull != true;

  // === Timer Settings ===

  int? get timerMinutes => _session?.timerMinutes;

  // === Start Player ===

  int get startPlayerIndex => _session?.startPlayerIndex ?? 0;

  Player? get startPlayer =>
      players.isNotEmpty ? players[startPlayerIndex] : null;

  // === Time Tracking ===

  Map<String, Duration> get playerTimes => _session?.playerTimes ?? {};

  /// Get total time for a specific player
  Duration getPlayerTime(String playerId) =>
      playerTimes[playerId] ?? Duration.zero;

  // === Session Lifecycle ===

  /// Create a new session as leader
  Future<void> createSession(String leaderName) async {
    final s = await _p2p.createSession(leaderName: leaderName);
    _session = s;
    _myPlayerId = s.leaderId;
    _subscribeToEvents();
    notifyListeners();
  }

  /// Start discovery for nearby sessions
  Future<void> startDiscovery() async {
    await _p2p.startDiscovery();
  }

  /// Stop discovery
  Future<void> stopDiscovery() async {
    await _p2p.stopDiscovery();
  }

  /// Stream of discovered sessions
  Stream<DiscoveredSession> get discoveredSessions => _p2p.discoveredSessions;

  /// Get connection info for the current session (if hosting).
  /// Returns "IP:PORT" format for WiFi connections, null otherwise.
  String? get hostConnectionInfo => _p2p.hostConnectionInfo;

  /// Join an existing session by code
  /// [connectionInfo] is optional - if provided (format: "IP:PORT"), connects
  /// directly without requiring prior discovery. Used for QR code joining.
  Future<void> joinSession(
    String code,
    String playerName, {
    String? connectionInfo,
  }) async {
    final s = await _p2p.joinSession(
      code: code,
      playerName: playerName,
      connectionInfo: connectionInfo,
    );
    _session = s;
    _myPlayerId = s.players.last.id;
    _subscribeToEvents();
    notifyListeners();
  }

  /// Leave the current session
  Future<void> leaveSession() async {
    if (_session == null) return;

    await _p2p.leaveSession(sessionId: _session!.id);
    await _screenService.disableWakeLock();

    _cancelSubscriptions();
    _session = null;
    _myPlayerId = null;
    notifyListeners();
  }

  // === Game Phase Management ===

  /// Start the game (leader only)
  Future<void> startGame() async {
    if (!canStartGame) return;

    // Enable wake lock for active game
    await _screenService.enableWakeLock();

    await _p2p.startGame(sessionId: _session!.id);

    // Update local state
    _session = _session!.copyWith(
      phase: GamePhase.active,
      currentIndex: _session!.startPlayerIndex,
      currentTurnStartTime: DateTime.now(),
    );
    notifyListeners();
  }

  /// End the game (leader only)
  Future<void> endGame() async {
    if (!isLeader || _session == null) return;

    // Record current player's time if game is active
    if (phase == GamePhase.active) {
      _recordCurrentTurnTime();
    }

    // Disable wake lock
    await _screenService.disableWakeLock();

    await _p2p.endGame(sessionId: _session!.id);

    _session = _session!.copyWith(
      phase: GamePhase.ended,
      seqNo: _session!.seqNo + 1,
      clearTurnStartTime: true,
    );
    notifyListeners();
  }

  /// Return to lobby after game ends
  void returnToLobby() {
    _cancelSubscriptions();
    _session = null;
    _myPlayerId = null;
    notifyListeners();
  }

  // === Turn Management ===

  /// Pass turn to the next player (records time for current player)
  Future<void> passTurnToNext() async {
    if (_session == null || phase != GamePhase.active) return;

    // Record elapsed time for current player
    _recordCurrentTurnTime();

    final nextIdx = (_session!.currentIndex + 1) % players.length;
    final next = players[nextIdx];

    // Update local state with new turn start time
    _session = _session!.copyWith(
      currentIndex: nextIdx,
      currentTurnStartTime: DateTime.now(),
    );

    await _p2p.passTurn(sessionId: _session!.id, toPlayerId: next.id);
    notifyListeners();
  }

  // === Player Management ===

  /// Reorder players (leader only, setup phase)
  void reorderPlayers(int oldIndex, int newIndex) {
    if (_session == null || !isLeader) return;

    final list = [..._session!.players];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    // Adjust start player index if needed
    var newStartIndex = _session!.startPlayerIndex;
    final startPlayerId = _session!.startPlayer.id;
    newStartIndex = list.indexWhere((p) => p.id == startPlayerId);
    if (newStartIndex < 0) newStartIndex = 0;

    _session = _session!.copyWith(
      players: list,
      startPlayerIndex: newStartIndex,
    );

    // Notify P2P service
    _p2p.reorderPlayers(
      sessionId: _session!.id,
      playerIds: list.map((p) => p.id).toList(),
    );

    notifyListeners();
  }

  /// Set the start player (leader only, setup phase)
  void setStartPlayer(int index) {
    if (!isLeader || _session == null) return;
    if (index < 0 || index >= players.length) return;

    _session = _session!.copyWith(
      startPlayerIndex: index,
    );

    _p2p.updateStartPlayer(
      sessionId: _session!.id,
      startPlayerIndex: index,
    );

    notifyListeners();
  }

  // === Timer Settings ===

  /// Set timer minutes (leader only)
  /// Pass null to disable timer
  Future<void> setTimerMinutes(int? minutes) async {
    if (!isLeader || _session == null) return;

    // Validate range
    if (minutes != null) {
      if (minutes < Session.minTimerMinutes ||
          minutes > Session.maxTimerMinutes) {
        return;
      }
    }

    _session = _session!.copyWith(
      timerMinutes: minutes,
      clearTimer: minutes == null,
    );

    await _p2p.updateTimerSetting(
      sessionId: _session!.id,
      minutes: minutes,
    );

    notifyListeners();
  }

  // === Private Methods ===

  /// Record elapsed time for the current player
  void _recordCurrentTurnTime() {
    if (_session?.currentTurnStartTime == null) return;

    final elapsed =
        DateTime.now().difference(_session!.currentTurnStartTime!);
    final playerId = currentPlayer!.id;
    final newTimes = Map<String, Duration>.from(_session!.playerTimes);
    newTimes[playerId] = (newTimes[playerId] ?? Duration.zero) + elapsed;

    _session = _session!.copyWith(playerTimes: newTimes);
  }

  /// Subscribe to P2P events
  void _subscribeToEvents() {
    _cancelSubscriptions();

    final s = _session;
    if (s == null) return;

    // Listen for turn changes
    _tokenSub = _p2p.onTokenChanged(sessionId: s.id).listen((evt) {
      if (_session == null || _session!.id != evt.sessionId) return;

      final toIdx =
          _session!.players.indexWhere((p) => p.id == evt.toPlayerId);
      if (toIdx >= 0) {
        _session = _session!.copyWith(
          currentIndex: toIdx,
          currentTurnStartTime: DateTime.now(),
          seqNo: evt.seqNo,
        );
        notifyListeners();
      }
    });

    // Listen for session state changes
    _stateSub = _p2p.onSessionStateChanged(sessionId: s.id).listen((evt) {
      if (_session == null || _session!.id != evt.sessionId) return;

      _session = _session!.copyWith(
        phase: evt.phase,
        timerMinutes: evt.timerMinutes,
        players: evt.players,
        currentIndex: evt.currentIndex,
        startPlayerIndex: evt.startPlayerIndex,
        seqNo: evt.seqNo,
        playerTimes: evt.finalTimes ?? _session!.playerTimes,
      );

      // Handle wake lock based on phase
      if (evt.phase == GamePhase.active) {
        _screenService.enableWakeLock();
      } else {
        _screenService.disableWakeLock();
      }

      notifyListeners();
    });

    // Listen for connection status changes
    _connectionSub =
        _p2p.onConnectionStatusChanged(sessionId: s.id).listen((evt) {
      if (_session == null || _session!.id != evt.sessionId) return;

      final playerIdx =
          _session!.players.indexWhere((p) => p.id == evt.playerId);
      if (playerIdx >= 0) {
        final updatedPlayers = [..._session!.players];
        updatedPlayers[playerIdx] =
            updatedPlayers[playerIdx].copyWith(connectionStatus: evt.status);
        _session = _session!.copyWith(players: updatedPlayers);
        notifyListeners();
      }
    });
  }

  /// Cancel all event subscriptions
  void _cancelSubscriptions() {
    _tokenSub?.cancel();
    _tokenSub = null;
    _stateSub?.cancel();
    _stateSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    _p2p.dispose();
    _screenService.dispose();
    super.dispose();
  }
}
