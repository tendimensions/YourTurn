// WiFi-based P2P service using TCP/IP sockets for cross-platform connectivity.
//
// This service enables iOS and Android devices to communicate when connected
// to the same WiFi network. It uses:
// - TCP sockets for reliable message delivery
// - UDP broadcast for session discovery on the local network
//
// Note: This is the current cross-platform solution. While not ideal (requires
// WiFi infrastructure), it provides simple and reliable connectivity without
// complex BLE GATT implementations.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models.dart';
import 'p2p_service.dart';

/// WiFi-based P2P service for cross-platform connectivity.
///
/// Host device runs a TCP server and broadcasts session info via UDP.
/// Player devices listen for UDP broadcasts and connect via TCP.
class WifiP2PService implements P2PService {
  static const int _defaultPort = 0; // Let OS assign port
  static const int _broadcastPort = 41234; // Fixed port for UDP discovery
  static const String _broadcastAddress = '255.255.255.255';
  static const Duration _broadcastInterval = Duration(seconds: 2);
  static const Duration _discoveryTimeout = Duration(seconds: 30);

  final _uuid = const Uuid();

  // Server (host) state
  ServerSocket? _server;
  final List<_ClientConnection> _clients = [];
  Timer? _broadcastTimer;
  RawDatagramSocket? _broadcastSocket;

  // Client (player) state
  Socket? _clientSocket;
  RawDatagramSocket? _discoverySocket;
  Timer? _discoveryTimer;
  bool _isDiscovering = false;

  // Session state
  Session? _currentSession;
  bool _isHost = false;
  String? _localPlayerId;
  int _seqNo = 0;

  // Stream controllers
  final _discoveredCtrl = StreamController<DiscoveredSession>.broadcast();
  final Map<String, StreamController<TokenEvent>> _tokenCtrls = {};
  final Map<String, StreamController<SessionStateEvent>> _stateCtrls = {};
  final Map<String, StreamController<ConnectionStatusEvent>> _connectionCtrls =
      {};

  // Track discovered sessions to avoid duplicates
  final Map<String, DiscoveredSession> _discoveredSessions = {};

  @override
  Stream<DiscoveredSession> get discoveredSessions => _discoveredCtrl.stream;

  @override
  Future<Session> createSession({required String leaderName}) async {
    final id = _uuid.v4();
    final code = Session.shortCodeFromId(id);

    // Start TCP server
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, _defaultPort);
    final port = _server!.port;

    print('[WiFi P2P] Server started on port $port');

    // Listen for incoming connections
    _server!.listen(
      _handleIncomingConnection,
      onError: (e) => print('[WiFi P2P] Server error: $e'),
      onDone: () => print('[WiFi P2P] Server closed'),
    );

    // Start UDP broadcast
    await _startBroadcasting(code, leaderName, port, false);

    // Create session
    _localPlayerId = leaderName;
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
    _isHost = true;

    // Setup stream controllers for this session
    _tokenCtrls[id] = StreamController<TokenEvent>.broadcast();
    _stateCtrls[id] = StreamController<SessionStateEvent>.broadcast();
    _connectionCtrls[id] = StreamController<ConnectionStatusEvent>.broadcast();

    return _currentSession!;
  }

  Future<void> _startBroadcasting(
    String code,
    String leaderName,
    int port,
    bool isInProgress,
  ) async {
    try {
      _broadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _broadcastSocket!.broadcastEnabled = true;

      _broadcastTimer = Timer.periodic(_broadcastInterval, (_) {
        _sendBroadcast(code, leaderName, port, isInProgress);
      });

      // Send initial broadcast
      _sendBroadcast(code, leaderName, port, isInProgress);
    } catch (e) {
      print('[WiFi P2P] Failed to start broadcasting: $e');
    }
  }

  void _sendBroadcast(
    String code,
    String leaderName,
    int port,
    bool isInProgress,
  ) {
    if (_broadcastSocket == null) return;

    final message = json.encode({
      'type': 'sessionAnnounce',
      'code': code,
      'leaderName': leaderName,
      'port': port,
      'isInProgress': isInProgress,
    });

    try {
      _broadcastSocket!.send(
        utf8.encode(message),
        InternetAddress(_broadcastAddress),
        _broadcastPort,
      );
    } catch (e) {
      print('[WiFi P2P] Broadcast send error: $e');
    }
  }

  void _stopBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
  }

  void _handleIncomingConnection(Socket socket) {
    final clientAddr = '${socket.remoteAddress.address}:${socket.remotePort}';
    print('[WiFi P2P] New connection from $clientAddr');

    final client = _ClientConnection(socket);
    _clients.add(client);

    // Setup data listener
    socket.listen(
      (data) => _handleClientData(client, data),
      onError: (e) {
        print('[WiFi P2P] Client error: $e');
        _handleClientDisconnect(client);
      },
      onDone: () => _handleClientDisconnect(client),
    );
  }

  void _handleClientData(_ClientConnection client, List<int> data) {
    try {
      final message = utf8.decode(data);
      final parsed = json.decode(message) as Map<String, dynamic>;
      _handleMessage(parsed, client);
    } catch (e) {
      print('[WiFi P2P] Failed to parse client data: $e');
    }
  }

  void _handleClientDisconnect(_ClientConnection client) {
    print('[WiFi P2P] Client disconnected: ${client.playerId}');
    _clients.remove(client);

    if (client.playerId != null && _currentSession != null) {
      // Notify about disconnection
      _connectionCtrls[_currentSession!.id]?.add(ConnectionStatusEvent(
        sessionId: _currentSession!.id,
        playerId: client.playerId!,
        status: ConnectionStatus.disconnected,
      ));

      // Remove player from session
      _currentSession = _currentSession!.copyWith(
        players: _currentSession!.players
            .where((p) => p.id != client.playerId)
            .toList(),
      );

      // Broadcast updated player list
      _broadcastToClients({
        'type': 'playerLeft',
        'playerId': client.playerId,
      });
    }

    client.socket.close();
  }

  @override
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;
    _discoveredSessions.clear();

    try {
      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _broadcastPort,
        reuseAddress: true,
      );
      _discoverySocket!.broadcastEnabled = true;

      print('[WiFi P2P] Discovery started on port $_broadcastPort');

      _discoverySocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _discoverySocket!.receive();
          if (datagram != null) {
            _handleDiscoveryPacket(datagram);
          }
        }
      });

      // Set discovery timeout
      _discoveryTimer = Timer(_discoveryTimeout, () {
        print('[WiFi P2P] Discovery timeout');
      });
    } catch (e) {
      print('[WiFi P2P] Failed to start discovery: $e');
      _isDiscovering = false;
    }
  }

  void _handleDiscoveryPacket(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data);
      final parsed = json.decode(message) as Map<String, dynamic>;

      if (parsed['type'] == 'sessionAnnounce') {
        final code = parsed['code'] as String;
        final leaderName = parsed['leaderName'] as String;
        final port = parsed['port'] as int;
        final isInProgress = parsed['isInProgress'] as bool? ?? false;

        // Store host address for later connection
        final hostAddress = datagram.address.address;

        final session = DiscoveredSession(
          code: code,
          advertisedBy: leaderName,
          isInProgress: isInProgress,
        );

        // Store with host info for connection
        _discoveredSessions[code] = session;
        _discoveredSessions['${code}_host'] = DiscoveredSession(
          code: '$hostAddress:$port',
          advertisedBy: leaderName,
          isInProgress: isInProgress,
        );

        _discoveredCtrl.add(session);
        print('[WiFi P2P] Discovered session: $code at $hostAddress:$port');
      }
    } catch (e) {
      print('[WiFi P2P] Failed to parse discovery packet: $e');
    }
  }

  @override
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _discoverySocket?.close();
    _discoverySocket = null;
    print('[WiFi P2P] Discovery stopped');
  }

  @override
  Future<Session> joinSession({
    required String code,
    required String playerName,
  }) async {
    // Find the host info from discovered sessions
    final hostInfo = _discoveredSessions['${code}_host'];
    if (hostInfo == null) {
      throw Exception('Session not found. Make sure you\'re on the same WiFi network.');
    }

    final hostParts = hostInfo.code.split(':');
    final hostAddress = hostParts[0];
    final hostPort = int.parse(hostParts[1]);

    print('[WiFi P2P] Connecting to $hostAddress:$hostPort');

    // Connect to host
    _clientSocket = await Socket.connect(
      hostAddress,
      hostPort,
      timeout: const Duration(seconds: 10),
    );

    print('[WiFi P2P] Connected to host');

    // Setup listener
    final completer = Completer<Session>();
    _localPlayerId = playerName;
    _isHost = false;

    _clientSocket!.listen(
      (data) {
        try {
          final message = utf8.decode(data);
          final parsed = json.decode(message) as Map<String, dynamic>;
          _handleServerMessage(parsed, completer);
        } catch (e) {
          print('[WiFi P2P] Failed to parse server data: $e');
        }
      },
      onError: (e) {
        print('[WiFi P2P] Server connection error: $e');
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
      onDone: () {
        print('[WiFi P2P] Disconnected from server');
        _handleServerDisconnect();
      },
    );

    // Send join request
    _sendToServer({
      'type': 'joinRequest',
      'playerName': playerName,
      'playerId': playerName,
    });

    // Wait for session state response
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Join timeout'),
    );
  }

  void _handleServerMessage(
    Map<String, dynamic> message,
    Completer<Session>? joinCompleter,
  ) {
    final type = message['type'] as String?;

    switch (type) {
      case 'joinAccepted':
        final sessionId = message['sessionId'] as String;
        final sessionCode = message['code'] as String;
        final leaderId = message['leaderId'] as String;
        final playerNames =
            (message['players'] as List).cast<String>();
        final timerMinutes = message['timerMinutes'] as int?;
        final startPlayerIndex = message['startPlayerIndex'] as int? ?? 0;

        final players = playerNames
            .map((name) => Player(id: name, name: name))
            .toList();

        _currentSession = Session(
          id: sessionId,
          code: sessionCode,
          leaderId: leaderId,
          players: players,
          seqNo: 0,
          currentIndex: 0,
          phase: GamePhase.setup,
          timerMinutes: timerMinutes,
          startPlayerIndex: startPlayerIndex,
          playerTimes: {for (var p in players) p.id: Duration.zero},
        );

        // Setup stream controllers
        _tokenCtrls[sessionId] = StreamController<TokenEvent>.broadcast();
        _stateCtrls[sessionId] = StreamController<SessionStateEvent>.broadcast();
        _connectionCtrls[sessionId] =
            StreamController<ConnectionStatusEvent>.broadcast();

        joinCompleter?.complete(_currentSession!);
        break;

      case 'playerJoined':
        final playerId = message['playerId'] as String;
        final playerName = message['playerName'] as String;
        if (_currentSession != null) {
          final newPlayer = Player(id: playerId, name: playerName);
          if (!_currentSession!.players.any((p) => p.id == playerId)) {
            _currentSession = _currentSession!.copyWith(
              players: [..._currentSession!.players, newPlayer],
            );
          }
          _connectionCtrls[_currentSession!.id]?.add(ConnectionStatusEvent(
            sessionId: _currentSession!.id,
            playerId: playerId,
            status: ConnectionStatus.connected,
          ));
          _emitStateUpdate();
        }
        break;

      case 'playerLeft':
        final playerId = message['playerId'] as String;
        if (_currentSession != null) {
          _currentSession = _currentSession!.copyWith(
            players:
                _currentSession!.players.where((p) => p.id != playerId).toList(),
          );
          _connectionCtrls[_currentSession!.id]?.add(ConnectionStatusEvent(
            sessionId: _currentSession!.id,
            playerId: playerId,
            status: ConnectionStatus.disconnected,
          ));
          _emitStateUpdate();
        }
        break;

      case 'gameStart':
        if (_currentSession != null) {
          final startPlayerIndex = message['startPlayerIndex'] as int? ?? 0;
          _currentSession = _currentSession!.copyWith(
            phase: GamePhase.active,
            currentIndex: startPlayerIndex,
            startPlayerIndex: startPlayerIndex,
          );
          _stateCtrls[_currentSession!.id]?.add(SessionStateEvent(
            sessionId: _currentSession!.id,
            seqNo: ++_seqNo,
            phase: GamePhase.active,
            players: _currentSession!.players,
            currentIndex: startPlayerIndex,
            startPlayerIndex: startPlayerIndex,
            timerMinutes: _currentSession!.timerMinutes,
          ));
        }
        break;

      case 'gameEnd':
        if (_currentSession != null) {
          final finalTimes = (message['finalTimes'] as Map?)?.map(
            (k, v) => MapEntry(k as String, Duration(milliseconds: v as int)),
          );
          _currentSession = _currentSession!.copyWith(
            phase: GamePhase.ended,
            playerTimes: finalTimes ?? _currentSession!.playerTimes,
          );
          _stateCtrls[_currentSession!.id]?.add(SessionStateEvent(
            sessionId: _currentSession!.id,
            seqNo: ++_seqNo,
            phase: GamePhase.ended,
            players: _currentSession!.players,
            currentIndex: _currentSession!.currentIndex,
            startPlayerIndex: _currentSession!.startPlayerIndex,
            finalTimes: finalTimes,
          ));
        }
        break;

      case 'turnChange':
        final fromPlayerId = message['fromPlayerId'] as String;
        final toPlayerId = message['toPlayerId'] as String;
        if (_currentSession != null) {
          final toIndex =
              _currentSession!.players.indexWhere((p) => p.id == toPlayerId);
          if (toIndex >= 0) {
            _currentSession = _currentSession!.copyWith(currentIndex: toIndex);
          }
          _tokenCtrls[_currentSession!.id]?.add(TokenEvent(
            sessionId: _currentSession!.id,
            seqNo: ++_seqNo,
            fromPlayerId: fromPlayerId,
            toPlayerId: toPlayerId,
          ));
        }
        break;

      case 'timerUpdate':
        final minutes = message['minutes'] as int?;
        if (_currentSession != null) {
          _currentSession = _currentSession!.copyWith(
            timerMinutes: minutes,
            clearTimer: minutes == null,
          );
          _stateCtrls[_currentSession!.id]?.add(SessionStateEvent(
            sessionId: _currentSession!.id,
            seqNo: ++_seqNo,
            phase: _currentSession!.phase,
            timerMinutes: minutes,
            players: _currentSession!.players,
            currentIndex: _currentSession!.currentIndex,
            startPlayerIndex: _currentSession!.startPlayerIndex,
          ));
        }
        break;

      case 'startPlayerUpdate':
        final startPlayerIndex = message['startPlayerIndex'] as int;
        if (_currentSession != null) {
          _currentSession = _currentSession!.copyWith(
            startPlayerIndex: startPlayerIndex,
          );
          _emitStateUpdate();
        }
        break;

      case 'playersReorder':
        final playerIds = (message['playerIds'] as List).cast<String>();
        if (_currentSession != null) {
          final reorderedPlayers = <Player>[];
          for (final id in playerIds) {
            final player = _currentSession!.players.firstWhere(
              (p) => p.id == id,
              orElse: () => Player(id: id, name: id),
            );
            reorderedPlayers.add(player);
          }
          _currentSession = _currentSession!.copyWith(players: reorderedPlayers);
          _emitStateUpdate();
        }
        break;
    }
  }

  void _emitStateUpdate() {
    if (_currentSession == null) return;
    _stateCtrls[_currentSession!.id]?.add(SessionStateEvent(
      sessionId: _currentSession!.id,
      seqNo: ++_seqNo,
      phase: _currentSession!.phase,
      timerMinutes: _currentSession!.timerMinutes,
      players: _currentSession!.players,
      currentIndex: _currentSession!.currentIndex,
      startPlayerIndex: _currentSession!.startPlayerIndex,
    ));
  }

  void _handleServerDisconnect() {
    if (_currentSession != null) {
      // Host disconnected - end game
      _stateCtrls[_currentSession!.id]?.add(SessionStateEvent(
        sessionId: _currentSession!.id,
        seqNo: ++_seqNo,
        phase: GamePhase.ended,
        players: _currentSession!.players,
        currentIndex: _currentSession!.currentIndex,
        startPlayerIndex: _currentSession!.startPlayerIndex,
      ));
    }
    _currentSession = null;
    _clientSocket = null;
  }

  void _handleMessage(Map<String, dynamic> message, _ClientConnection client) {
    final type = message['type'] as String?;

    switch (type) {
      case 'joinRequest':
        _handleJoinRequest(message, client);
        break;
      case 'passTurn':
        _handlePassTurn(message);
        break;
    }
  }

  void _handleJoinRequest(
    Map<String, dynamic> message,
    _ClientConnection client,
  ) {
    if (_currentSession == null) return;

    final playerName = message['playerName'] as String;
    final playerId = message['playerId'] as String;

    // Check if session is full or in progress
    if (_currentSession!.isFull) {
      _sendToClient(client, {'type': 'joinRejected', 'reason': 'Session is full'});
      return;
    }
    if (_currentSession!.isActive) {
      _sendToClient(client, {'type': 'joinRejected', 'reason': 'Game in progress'});
      return;
    }

    // Add player
    final newPlayer = Player(id: playerId, name: playerName);
    _currentSession = _currentSession!.copyWith(
      players: [..._currentSession!.players, newPlayer],
      playerTimes: {
        ..._currentSession!.playerTimes,
        playerId: Duration.zero,
      },
    );

    client.playerId = playerId;

    // Send acceptance with current state
    _sendToClient(client, {
      'type': 'joinAccepted',
      'sessionId': _currentSession!.id,
      'code': _currentSession!.code,
      'leaderId': _currentSession!.leaderId,
      'players': _currentSession!.players.map((p) => p.name).toList(),
      'timerMinutes': _currentSession!.timerMinutes,
      'startPlayerIndex': _currentSession!.startPlayerIndex,
    });

    // Notify all other clients
    _broadcastToClients({
      'type': 'playerJoined',
      'playerId': playerId,
      'playerName': playerName,
    }, exclude: client);

    // Emit connection event locally
    _connectionCtrls[_currentSession!.id]?.add(ConnectionStatusEvent(
      sessionId: _currentSession!.id,
      playerId: playerId,
      status: ConnectionStatus.connected,
    ));

    // Emit state update locally
    _emitStateUpdate();

    print('[WiFi P2P] Player joined: $playerName');
  }

  void _handlePassTurn(Map<String, dynamic> message) {
    if (_currentSession == null || !_isHost) return;

    final fromPlayerId = message['fromPlayerId'] as String;
    final toPlayerId = message['toPlayerId'] as String;

    final toIndex =
        _currentSession!.players.indexWhere((p) => p.id == toPlayerId);
    if (toIndex >= 0) {
      _currentSession = _currentSession!.copyWith(currentIndex: toIndex);

      // Broadcast to all clients
      _broadcastToClients({
        'type': 'turnChange',
        'fromPlayerId': fromPlayerId,
        'toPlayerId': toPlayerId,
      });

      // Emit locally
      _tokenCtrls[_currentSession!.id]?.add(TokenEvent(
        sessionId: _currentSession!.id,
        seqNo: ++_seqNo,
        fromPlayerId: fromPlayerId,
        toPlayerId: toPlayerId,
      ));
    }
  }

  void _sendToClient(_ClientConnection client, Map<String, dynamic> message) {
    try {
      final data = json.encode(message);
      client.socket.write(data);
    } catch (e) {
      print('[WiFi P2P] Failed to send to client: $e');
    }
  }

  void _sendToServer(Map<String, dynamic> message) {
    if (_clientSocket == null) return;
    try {
      final data = json.encode(message);
      _clientSocket!.write(data);
    } catch (e) {
      print('[WiFi P2P] Failed to send to server: $e');
    }
  }

  void _broadcastToClients(
    Map<String, dynamic> message, {
    _ClientConnection? exclude,
  }) {
    for (final client in _clients) {
      if (client != exclude) {
        _sendToClient(client, message);
      }
    }
  }

  @override
  Future<void> startGame({required String sessionId}) async {
    if (_currentSession == null || !_isHost) return;

    _currentSession = _currentSession!.copyWith(
      phase: GamePhase.active,
      currentIndex: _currentSession!.startPlayerIndex,
      currentTurnStartTime: DateTime.now(),
    );

    // Update broadcast to show in progress
    _stopBroadcasting();
    await _startBroadcasting(
      _currentSession!.code,
      _currentSession!.leaderId,
      _server!.port,
      true,
    );

    // Broadcast to all clients
    _broadcastToClients({
      'type': 'gameStart',
      'startPlayerIndex': _currentSession!.startPlayerIndex,
    });

    // Emit locally
    _stateCtrls[sessionId]?.add(SessionStateEvent(
      sessionId: sessionId,
      seqNo: ++_seqNo,
      phase: GamePhase.active,
      players: _currentSession!.players,
      currentIndex: _currentSession!.startPlayerIndex,
      startPlayerIndex: _currentSession!.startPlayerIndex,
      timerMinutes: _currentSession!.timerMinutes,
    ));
  }

  @override
  Future<void> endGame({required String sessionId}) async {
    if (_currentSession == null || !_isHost) return;

    _currentSession = _currentSession!.copyWith(phase: GamePhase.ended);

    final finalTimes = _currentSession!.playerTimes.map(
      (k, v) => MapEntry(k, v.inMilliseconds),
    );

    // Broadcast to all clients
    _broadcastToClients({
      'type': 'gameEnd',
      'finalTimes': finalTimes,
    });

    // Emit locally
    _stateCtrls[sessionId]?.add(SessionStateEvent(
      sessionId: sessionId,
      seqNo: ++_seqNo,
      phase: GamePhase.ended,
      players: _currentSession!.players,
      currentIndex: _currentSession!.currentIndex,
      startPlayerIndex: _currentSession!.startPlayerIndex,
      finalTimes: _currentSession!.playerTimes,
    ));

    _stopBroadcasting();
  }

  @override
  Future<void> updateTimerSetting({
    required String sessionId,
    int? minutes,
  }) async {
    if (_currentSession == null || !_isHost) return;

    _currentSession = _currentSession!.copyWith(
      timerMinutes: minutes,
      clearTimer: minutes == null,
    );

    // Broadcast to all clients
    _broadcastToClients({
      'type': 'timerUpdate',
      'minutes': minutes,
    });

    // Emit locally
    _stateCtrls[sessionId]?.add(SessionStateEvent(
      sessionId: sessionId,
      seqNo: ++_seqNo,
      phase: _currentSession!.phase,
      timerMinutes: minutes,
      players: _currentSession!.players,
      currentIndex: _currentSession!.currentIndex,
      startPlayerIndex: _currentSession!.startPlayerIndex,
    ));
  }

  @override
  Future<void> updateStartPlayer({
    required String sessionId,
    required int startPlayerIndex,
  }) async {
    if (_currentSession == null || !_isHost) return;

    _currentSession = _currentSession!.copyWith(
      startPlayerIndex: startPlayerIndex,
    );

    // Broadcast to all clients
    _broadcastToClients({
      'type': 'startPlayerUpdate',
      'startPlayerIndex': startPlayerIndex,
    });

    // Emit locally
    _emitStateUpdate();
  }

  @override
  Future<void> reorderPlayers({
    required String sessionId,
    required List<String> playerIds,
  }) async {
    if (_currentSession == null || !_isHost) return;

    final reorderedPlayers = <Player>[];
    for (final id in playerIds) {
      final player = _currentSession!.players.firstWhere(
        (p) => p.id == id,
        orElse: () => Player(id: id, name: id),
      );
      reorderedPlayers.add(player);
    }

    _currentSession = _currentSession!.copyWith(players: reorderedPlayers);

    // Broadcast to all clients
    _broadcastToClients({
      'type': 'playersReorder',
      'playerIds': playerIds,
    });

    // Emit locally
    _emitStateUpdate();
  }

  @override
  Future<void> passTurn({
    required String sessionId,
    required String toPlayerId,
  }) async {
    if (_currentSession == null) return;

    final fromPlayerId = _currentSession!.currentPlayer.id;

    if (_isHost) {
      // Host handles directly
      _handlePassTurn({
        'fromPlayerId': fromPlayerId,
        'toPlayerId': toPlayerId,
      });
    } else {
      // Client sends to server
      _sendToServer({
        'type': 'passTurn',
        'fromPlayerId': fromPlayerId,
        'toPlayerId': toPlayerId,
      });
    }
  }

  @override
  Stream<TokenEvent> onTokenChanged({required String sessionId}) {
    _tokenCtrls.putIfAbsent(
      sessionId,
      () => StreamController<TokenEvent>.broadcast(),
    );
    return _tokenCtrls[sessionId]!.stream;
  }

  @override
  Stream<SessionStateEvent> onSessionStateChanged({required String sessionId}) {
    _stateCtrls.putIfAbsent(
      sessionId,
      () => StreamController<SessionStateEvent>.broadcast(),
    );
    return _stateCtrls[sessionId]!.stream;
  }

  @override
  Stream<ConnectionStatusEvent> onConnectionStatusChanged({
    required String sessionId,
  }) {
    _connectionCtrls.putIfAbsent(
      sessionId,
      () => StreamController<ConnectionStatusEvent>.broadcast(),
    );
    return _connectionCtrls[sessionId]!.stream;
  }

  @override
  Future<void> leaveSession({required String sessionId}) async {
    if (_isHost) {
      // Host leaving ends the session for everyone
      await endGame(sessionId: sessionId);

      // Close all client connections
      for (final client in _clients) {
        client.socket.close();
      }
      _clients.clear();

      // Stop server
      await _server?.close();
      _server = null;

      _stopBroadcasting();
    } else {
      // Client leaving
      _clientSocket?.close();
      _clientSocket = null;
    }

    _currentSession = null;
    _isHost = false;
    _localPlayerId = null;
  }

  @override
  Future<void> dispose() async {
    await stopDiscovery();
    _stopBroadcasting();

    // Close server
    await _server?.close();
    _server = null;

    // Close client connections
    for (final client in _clients) {
      client.socket.close();
    }
    _clients.clear();

    // Close client socket
    _clientSocket?.close();
    _clientSocket = null;

    // Close stream controllers
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

    _currentSession = null;
  }
}

/// Represents a connected client (player)
class _ClientConnection {
  final Socket socket;
  String? playerId;

  _ClientConnection(this.socket);
}
