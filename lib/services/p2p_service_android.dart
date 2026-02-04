// Android implementation of P2PService using Nearby Connections via MethodChannel.
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models.dart';
import 'p2p_service.dart';

class AndroidP2PService implements P2PService {
  static const MethodChannel _channel = MethodChannel('yourturn/p2p');
  static const EventChannel _eventChannel = EventChannel('yourturn/p2p_events');

  final _uuid = const Uuid();
  final _discoveredCtrl = StreamController<DiscoveredSession>.broadcast();
  final Map<String, StreamController<TokenEvent>> _tokenCtrls = {};
  final Map<String, StreamController<SessionStateEvent>> _stateCtrls = {};
  final Map<String, StreamController<ConnectionStatusEvent>> _connectionCtrls =
      {};

  StreamSubscription? _eventSubscription;
  Session? _currentSession;

  AndroidP2PService() {
    _setupEventListener();
  }

  void _setupEventListener() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _handleEvent(Map<String, dynamic>.from(event));
        }
      },
      onError: (error) {
        print('[Android P2P] Event stream error: $error');
      },
    );
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;

    switch (type) {
      case 'sessionDiscovered':
        final data = event['data'] as Map?;
        if (data != null) {
          _discoveredCtrl.add(DiscoveredSession(
            code: data['code'] as String? ?? '',
            advertisedBy: data['advertisedBy'] as String? ?? '',
            isInProgress: data['isInProgress'] as bool? ?? false,
          ));
        }
        break;

      case 'peerConnected':
        final playerId = event['playerId'] as String?;
        final sessionId = event['sessionId'] as String?;
        if (playerId != null && sessionId != null) {
          _connectionCtrls[sessionId]?.add(ConnectionStatusEvent(
            sessionId: sessionId,
            playerId: playerId,
            status: ConnectionStatus.connected,
          ));
        }
        break;

      case 'peerDisconnected':
        final playerId = event['playerId'] as String?;
        if (playerId != null && _currentSession != null) {
          _connectionCtrls[_currentSession!.id]?.add(ConnectionStatusEvent(
            sessionId: _currentSession!.id,
            playerId: playerId,
            status: ConnectionStatus.disconnected,
          ));
        }
        break;

      case 'message':
        final data = event['data'] as Map?;
        if (data != null) {
          _handleP2PMessage(Map<String, dynamic>.from(data));
        }
        break;

      case 'error':
        final message = event['message'] as String?;
        print('[Android P2P] Error: $message');
        break;
    }
  }

  void _handleP2PMessage(Map<String, dynamic> message) {
    final messageType = message['type'] as String?;
    final sessionId = message['sessionId'] as String? ?? _currentSession?.id;

    if (sessionId == null) return;

    switch (messageType) {
      case 'turnChange':
        final toPlayerId = message['toPlayerId'] as String?;
        final fromPlayerId = message['fromPlayerId'] as String?;
        final seqNo = message['seqNo'] as int? ?? 0;
        if (toPlayerId != null && fromPlayerId != null) {
          _tokenCtrls[sessionId]?.add(TokenEvent(
            sessionId: sessionId,
            seqNo: seqNo,
            fromPlayerId: fromPlayerId,
            toPlayerId: toPlayerId,
          ));
        }
        break;

      case 'gameStart':
        final seqNo = message['seqNo'] as int? ?? 0;
        _stateCtrls[sessionId]?.add(SessionStateEvent(
          sessionId: sessionId,
          seqNo: seqNo,
          phase: GamePhase.active,
          players: _currentSession?.players ?? [],
          currentIndex: _currentSession?.startPlayerIndex ?? 0,
          startPlayerIndex: _currentSession?.startPlayerIndex ?? 0,
        ));
        break;

      case 'gameEnd':
        final seqNo = message['seqNo'] as int? ?? 0;
        _stateCtrls[sessionId]?.add(SessionStateEvent(
          sessionId: sessionId,
          seqNo: seqNo,
          phase: GamePhase.ended,
          players: _currentSession?.players ?? [],
          currentIndex: _currentSession?.currentIndex ?? 0,
          startPlayerIndex: _currentSession?.startPlayerIndex ?? 0,
          finalTimes: _currentSession?.playerTimes,
        ));
        break;

      case 'timerUpdate':
        final minutes = message['minutes'] as int?;
        final seqNo = message['seqNo'] as int? ?? 0;
        _stateCtrls[sessionId]?.add(SessionStateEvent(
          sessionId: sessionId,
          seqNo: seqNo,
          phase: _currentSession?.phase ?? GamePhase.setup,
          timerMinutes: minutes,
          players: _currentSession?.players ?? [],
          currentIndex: _currentSession?.currentIndex ?? 0,
          startPlayerIndex: _currentSession?.startPlayerIndex ?? 0,
        ));
        break;

      case 'startPlayerUpdate':
        final startPlayerIndex = message['startPlayerIndex'] as int? ?? 0;
        final seqNo = message['seqNo'] as int? ?? 0;
        _stateCtrls[sessionId]?.add(SessionStateEvent(
          sessionId: sessionId,
          seqNo: seqNo,
          phase: _currentSession?.phase ?? GamePhase.setup,
          players: _currentSession?.players ?? [],
          currentIndex: _currentSession?.currentIndex ?? 0,
          startPlayerIndex: startPlayerIndex,
        ));
        break;

      case 'playersReorder':
        final playerIds = (message['playerIds'] as List?)?.cast<String>() ?? [];
        final seqNo = message['seqNo'] as int? ?? 0;
        // Reorder local players list
        if (_currentSession != null) {
          final reorderedPlayers = <Player>[];
          for (final id in playerIds) {
            final player = _currentSession!.players.firstWhere(
              (p) => p.id == id,
              orElse: () => Player(id: id, name: id),
            );
            reorderedPlayers.add(player);
          }
          _stateCtrls[sessionId]?.add(SessionStateEvent(
            sessionId: sessionId,
            seqNo: seqNo,
            phase: _currentSession?.phase ?? GamePhase.setup,
            players: reorderedPlayers,
            currentIndex: _currentSession?.currentIndex ?? 0,
            startPlayerIndex: _currentSession?.startPlayerIndex ?? 0,
          ));
        }
        break;

      case 'sessionState':
        // Full state sync from host
        final players = (message['players'] as List?)?.cast<String>() ?? [];
        final seqNo = message['seqNo'] as int? ?? 0;
        final playerList =
            players.map((name) => Player(id: name, name: name)).toList();
        _stateCtrls[sessionId]?.add(SessionStateEvent(
          sessionId: sessionId,
          seqNo: seqNo,
          phase: _currentSession?.phase ?? GamePhase.setup,
          players: playerList,
          currentIndex: 0,
          startPlayerIndex: 0,
        ));
        break;

      case 'playerLeft':
        final playerId = message['playerId'] as String?;
        if (playerId != null) {
          _connectionCtrls[sessionId]?.add(ConnectionStatusEvent(
            sessionId: sessionId,
            playerId: playerId,
            status: ConnectionStatus.disconnected,
          ));
        }
        break;
    }
  }

  @override
  Stream<DiscoveredSession> get discoveredSessions => _discoveredCtrl.stream;

  @override
  String? get hostConnectionInfo => null; // Nearby Connections handles connections internally

  @override
  Future<Session> createSession({required String leaderName}) async {
    final id = _uuid.v4();
    final code = Session.shortCodeFromId(id);

    try {
      await _channel.invokeMethod('createSession', {
        'leaderName': leaderName,
        'sessionId': id,
        'sessionCode': code,
      });
    } catch (e) {
      print('[Android P2P] Failed to create session: $e');
      rethrow;
    }

    final leader = Player(id: leaderName, name: leaderName);
    _currentSession = Session(
      id: id,
      code: code,
      leaderId: leader.id,
      players: [leader],
      seqNo: 0,
      currentIndex: 0,
      phase: GamePhase.setup,
      playerTimes: {leader.id: Duration.zero},
    );
    _tokenCtrls[id] = StreamController<TokenEvent>.broadcast();
    _stateCtrls[id] = StreamController<SessionStateEvent>.broadcast();
    _connectionCtrls[id] = StreamController<ConnectionStatusEvent>.broadcast();

    return _currentSession!;
  }

  @override
  Future<void> startDiscovery() async {
    try {
      await _channel.invokeMethod('startDiscovery');
    } catch (e) {
      print('[Android P2P] Failed to start discovery: $e');
    }
  }

  @override
  Future<void> stopDiscovery() async {
    try {
      await _channel.invokeMethod('stopDiscovery');
    } catch (e) {
      print('[Android P2P] Failed to stop discovery: $e');
    }
  }

  @override
  Future<Session> joinSession({
    required String code,
    required String playerName,
    String? connectionInfo,
  }) async {
    // connectionInfo is ignored - Nearby Connections handles connections via discovery
    try {
      final result = await _channel.invokeMethod('joinSession', {
        'sessionCode': code,
        'playerName': playerName,
      });

      final data = result as Map?;
      final sessionId = data?['sessionId'] as String? ?? '';

      final player = Player(id: playerName, name: playerName);
      _currentSession = Session(
        id: sessionId,
        code: code,
        leaderId: '', // Will be updated from state sync
        players: [player], // Will be updated from state sync
        seqNo: 0,
        currentIndex: 0,
        phase: GamePhase.setup,
        playerTimes: {player.id: Duration.zero},
      );
      _tokenCtrls[sessionId] = StreamController<TokenEvent>.broadcast();
      _stateCtrls[sessionId] = StreamController<SessionStateEvent>.broadcast();
      _connectionCtrls[sessionId] =
          StreamController<ConnectionStatusEvent>.broadcast();

      return _currentSession!;
    } catch (e) {
      print('[Android P2P] Failed to join session: $e');
      rethrow;
    }
  }

  @override
  Future<void> startGame({required String sessionId}) async {
    try {
      await _channel.invokeMethod('startGame');
    } catch (e) {
      print('[Android P2P] Failed to start game: $e');
    }
  }

  @override
  Future<void> endGame({required String sessionId}) async {
    try {
      await _channel.invokeMethod('endGame');
    } catch (e) {
      print('[Android P2P] Failed to end game: $e');
    }
  }

  @override
  Future<void> updateTimerSetting({
    required String sessionId,
    int? minutes,
  }) async {
    try {
      await _channel.invokeMethod('updateTimerSetting', {
        'minutes': minutes,
      });
    } catch (e) {
      print('[Android P2P] Failed to update timer: $e');
    }
  }

  @override
  Future<void> updateStartPlayer({
    required String sessionId,
    required int startPlayerIndex,
  }) async {
    try {
      await _channel.invokeMethod('updateStartPlayer', {
        'startPlayerIndex': startPlayerIndex,
      });
    } catch (e) {
      print('[Android P2P] Failed to update start player: $e');
    }
  }

  @override
  Future<void> reorderPlayers({
    required String sessionId,
    required List<String> playerIds,
  }) async {
    try {
      await _channel.invokeMethod('reorderPlayers', {
        'playerIds': playerIds,
      });
    } catch (e) {
      print('[Android P2P] Failed to reorder players: $e');
    }
  }

  @override
  Future<void> passTurn({
    required String sessionId,
    required String toPlayerId,
  }) async {
    try {
      await _channel.invokeMethod('passTurn', {
        'toPlayerId': toPlayerId,
        'fromPlayerId': _currentSession?.currentPlayer.id ?? '',
      });
    } catch (e) {
      print('[Android P2P] Failed to pass turn: $e');
    }
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
    try {
      await _channel.invokeMethod('leaveSession');
    } catch (e) {
      print('[Android P2P] Failed to leave session: $e');
    }
    _currentSession = null;
  }

  @override
  Future<void> dispose() async {
    _eventSubscription?.cancel();
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
    try {
      await _channel.invokeMethod('cleanup');
    } catch (e) {
      print('[Android P2P] Failed to cleanup: $e');
    }
  }
}
