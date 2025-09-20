// This file defines a small interface for P2P operations.
// Today, the app uses an in-memory stub (see p2p_service_stub.dart).
// Later, you can implement a PlatformP2PService via MethodChannel to call
// MultipeerConnectivity (iOS) and Nearby Connections / BLE (Android).

import 'dart:async';
import '../models.dart';

abstract class P2PService {
  /// Emits discovered sessions (nearby groups within radio range).
  Stream<DiscoveredSession> get discoveredSessions;

  /// Start advertising/hosting a session as leader.
  Future<Session> createSession({required String leaderName});

  /// Start scanning for sessions.
  Future<void> startDiscovery();

  /// Join a session by short code. Returns the joined [Session] snapshot.
  Future<Session> joinSession({required String code, required String playerName});

  /// Send the "pass turn" token to the next player by ID.
  Future<void> passTurn({required String sessionId, required String toPlayerId});

  /// Subscribe to token changes (who's turn), ordered by seqNo.
  Stream<TokenEvent> onTokenChanged({required String sessionId});

  /// Optional: stop radios / clean up
  Future<void> dispose();
}

class DiscoveredSession {
  final String code;
  final String advertisedBy;
  DiscoveredSession({required this.code, required this.advertisedBy});
}

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
