// P2P Service interface for peer-to-peer communication.
//
// This defines the contract for P2P operations. Today, the app uses an
// in-memory stub (see p2p_service_stub.dart). Later, you can implement
// a PlatformP2PService via MethodChannel to call MultipeerConnectivity (iOS)
// and Nearby Connections / BLE (Android).

import 'dart:async';
import '../models.dart';

abstract class P2PService {
  /// Emits discovered sessions (nearby groups within radio range).
  Stream<DiscoveredSession> get discoveredSessions;

  /// Start advertising/hosting a session as leader.
  Future<Session> createSession({required String leaderName});

  /// Start scanning for sessions.
  Future<void> startDiscovery();

  /// Stop scanning for sessions.
  Future<void> stopDiscovery();

  /// Join a session by short code. Returns the joined [Session] snapshot.
  Future<Session> joinSession({
    required String code,
    required String playerName,
  });

  /// Start the game (transition from setup to active phase).
  /// Only callable by leader.
  Future<void> startGame({required String sessionId});

  /// End the game (transition to ended phase).
  /// Only callable by leader.
  Future<void> endGame({required String sessionId});

  /// Update timer settings for the session.
  /// [minutes] can be null (no timer) or 1-15.
  Future<void> updateTimerSetting({
    required String sessionId,
    int? minutes,
  });

  /// Update the start player index.
  Future<void> updateStartPlayer({
    required String sessionId,
    required int startPlayerIndex,
  });

  /// Reorder players in the session.
  Future<void> reorderPlayers({
    required String sessionId,
    required List<String> playerIds,
  });

  /// Send the "pass turn" token to the next player by ID.
  Future<void> passTurn({
    required String sessionId,
    required String toPlayerId,
  });

  /// Subscribe to token changes (who's turn), ordered by seqNo.
  Stream<TokenEvent> onTokenChanged({required String sessionId});

  /// Subscribe to session state changes (phase, settings, player list).
  Stream<SessionStateEvent> onSessionStateChanged({required String sessionId});

  /// Subscribe to connection status changes for players.
  Stream<ConnectionStatusEvent> onConnectionStatusChanged({
    required String sessionId,
  });

  /// Leave the current session.
  Future<void> leaveSession({required String sessionId});

  /// Optional: stop radios / clean up
  Future<void> dispose();
}

/// Represents a discovered nearby session
class DiscoveredSession {
  final String code;
  final String advertisedBy;
  final bool isInProgress;

  DiscoveredSession({
    required this.code,
    required this.advertisedBy,
    this.isInProgress = false,
  });
}

/// Event for turn changes
class TokenEvent {
  final String sessionId;
  final int seqNo;
  final String fromPlayerId;
  final String toPlayerId;

  TokenEvent({
    required this.sessionId,
    required this.seqNo,
    required this.fromPlayerId,
    required this.toPlayerId,
  });
}

/// Event for session state changes
class SessionStateEvent {
  final String sessionId;
  final int seqNo;
  final GamePhase phase;
  final int? timerMinutes;
  final List<Player> players;
  final int currentIndex;
  final int startPlayerIndex;
  final Map<String, Duration>? finalTimes;

  SessionStateEvent({
    required this.sessionId,
    required this.seqNo,
    required this.phase,
    this.timerMinutes,
    required this.players,
    required this.currentIndex,
    required this.startPlayerIndex,
    this.finalTimes,
  });
}

/// Event for connection status changes
class ConnectionStatusEvent {
  final String sessionId;
  final String playerId;
  final ConnectionStatus status;

  ConnectionStatusEvent({
    required this.sessionId,
    required this.playerId,
    required this.status,
  });
}
