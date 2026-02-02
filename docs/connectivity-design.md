# YourTurn - Connectivity Design Document

## Overview

This document captures the design decisions, technical approaches, and implementation strategies for the peer-to-peer (P2P) connectivity system in YourTurn. This is identified as one of the **most critical and complex components** of the application, requiring careful architecture and implementation planning.

## Critical Requirements

### Functional Requirements

- **Range**: 10-foot radius (typical tabletop gaming distance)
- **Player Count**: Support 2-8 devices simultaneously
- **Cross-Platform**: Must work seamlessly between iOS and Android devices
- **No Internet**: Local-only connectivity, no cloud dependencies
- **Real-Time**: Turn state updates must synchronize within 2 seconds
- **Reliability**: 99%+ successful message delivery
- **Background Operation**: Must work with app in background or screen locked
- **Battery Efficient**: Support 4+ hour gaming sessions

### Non-Functional Requirements

- **Setup Time**: < 30 seconds for all players to join
- **Automatic Discovery**: No manual code entry or QR scanning (relaxed - see cross-platform section)
- **Graceful Degradation**: Handle disconnections without game failure
- **Session Isolation**: Prevent accidental cross-table joining

---

## ⚠️ Cross-Platform Interoperability Challenge

### The Problem

**iOS and Android use incompatible native P2P protocols that cannot communicate with each other:**

| Platform | Native P2P Technology | Interoperates With |
|----------|----------------------|-------------------|
| iOS | MultipeerConnectivity | iOS only |
| Android | Nearby Connections (Google Play Services) | Android only |

This is a fundamental architectural limitation, not a bug. These are proprietary protocols designed by Apple and Google respectively, and they do not share a common transport layer for discovery or communication.

### Current Implementation Status

We have implemented platform-specific P2P services:

- **iOS**: `P2PHandler.swift` using MultipeerConnectivity → Works iOS-to-iOS ✅
- **Android**: `P2PHandler.kt` using Nearby Connections → Works Android-to-Android ✅
- **Cross-platform**: iOS ↔ Android → **Does NOT work** ❌

### Implications

1. **Same-platform sessions work**: iOS users can connect with other iOS users, Android with Android
2. **Mixed groups cannot use native P2P**: A gaming table with both iOS and Android devices needs an alternative solution
3. **QR codes help with discovery but not communication**: Scanning a QR code shares the session code, but the underlying P2P protocols still can't talk to each other

### QR Code Fallback (Implemented)

We've implemented QR code scanning as a **discovery fallback**:

- **Setup screen**: Displays QR code containing `yourturn:{sessionCode}`
- **Lobby screen**: "Scan QR Code" button opens camera scanner
- **Auto-join**: If player name is entered, scanning auto-joins the session

**Important**: QR codes solve the *discovery* problem (how do I find the session?) but NOT the *communication* problem (how do devices talk to each other?). Cross-platform communication requires one of the solutions discussed in the Open Discussion section below.

## Architecture Decision: Service Abstraction

### Core Principle

**Decision**: Implement an abstract `P2PService` interface with multiple platform-specific and technology-specific implementations that can be swapped based on device OS and capabilities.

### Rationale

1. **Platform Flexibility**: Different OSes have different optimal P2P technologies
2. **Technology Evolution**: Can adopt newer P2P standards without breaking app logic
3. **Testing**: Mock implementations for development/testing without hardware
4. **Progressive Enhancement**: Start simple (BLE), add complexity as needed
5. **Fallback Strategy**: Can chain multiple implementations for reliability

### Service Abstraction Layer

```dart
/// Abstract interface for peer-to-peer communication.
/// 
/// Platform-specific implementations handle device discovery,
/// connection management, and message routing.
abstract class P2PService {
  /// Initializes the P2P service.
  /// Must be called before any other operations.
  Future<bool> initialize();
  
  /// Starts discovering nearby sessions.
  /// Returns stream of discovered sessions.
  Stream<SessionInfo> startDiscovery();
  
  /// Stops active discovery.
  Future<void> stopDiscovery();
  
  /// Creates a new session as team leader.
  /// Returns session ID if successful.
  Future<String> createSession(String leaderName);
  
  /// Joins an existing session as player.
  Future<bool> joinSession(String sessionId, String playerName);
  
  /// Sends turn notification to all connected devices.
  Future<void> sendTurnNotification(TurnData turnData);
  
  /// Listens for incoming turn notifications.
  Stream<TurnData> listenForNotifications();
  
  /// Ends current session and disconnects all devices.
  Future<void> endSession();
  
  /// Gets current connection state.
  ConnectionState get connectionState;
  
  /// Gets list of connected players.
  List<ConnectedPlayer> get connectedPlayers;
  
  /// Disposes resources and cleanup.
  Future<void> dispose();
}
```

### Implementation Strategy

```dart
/// Factory for creating appropriate P2PService implementation
class P2PServiceFactory {
  /// Creates the optimal P2PService for current platform
  static P2PService create() {
    if (Platform.isIOS) {
      // Try MultipeerConnectivity first, fallback to BLE
      return P2PServiceComposite([
        P2PServiceMultipeer(),
        P2PServiceBLE(),
      ]);
    } else if (Platform.isAndroid) {
      // Try Nearby Connections first, fallback to BLE
      return P2PServiceComposite([
        P2PServiceNearby(),
        P2PServiceBLE(),
      ]);
    } else {
      // Stub for development/testing
      return P2PServiceStub();
    }
  }
  
  /// Creates BLE-only implementation (for testing/debugging)
  static P2PService createBLE() {
    return P2PServiceBLE();
  }
  
  /// Creates platform-specific implementation
  static P2PService createPlatformSpecific() {
    if (Platform.isIOS) return P2PServiceMultipeer();
    if (Platform.isAndroid) return P2PServiceNearby();
    return P2PServiceStub();
  }
}
```

## Technology Options Analysis

### Option 1: Bluetooth Low Energy (BLE)

#### Overview

Universal Bluetooth standard supported on all modern iOS and Android devices.

#### Technical Details

- **Protocol**: GATT (Generic Attribute Profile) server/client
- **Range**: 10-30 feet typical, up to 100 feet clear line-of-sight
- **Connections**: 7-8 simultaneous connections typical
- **Bandwidth**: ~1 Mbps (more than sufficient for small messages)
- **Power**: Very low power consumption

#### Implementation Approach

```
Team Leader Device:
├── GATT Server (advertises session)
├── Characteristic for session info (read)
├── Characteristic for turn notifications (notify)
└── Characteristic for player messages (write)

Player Devices:
├── GATT Client (scans for sessions)
├── Subscribes to turn notification characteristic
└── Writes to message characteristic
```

#### Pros

- ✅ True cross-platform (same code iOS/Android)
- ✅ No special platform-specific code required
- ✅ Well-documented, mature technology
- ✅ Good range for tabletop gaming (10+ feet)
- ✅ Battery efficient
- ✅ No internet connectivity required
- ✅ Fits within 8-player connection limit
- ✅ Less restrictive iOS permissions

#### Cons

- ❌ Platform BLE stack differences (iOS vs Android behavior)
- ❌ GATT server/client setup is verbose
- ❌ Can be affected by RF interference (crowded spaces)
- ❌ iOS background BLE restrictions (mitigated by wake-lock)
- ❌ Requires platform channels for full control
- ❌ Connection setup can be slow (5-10 seconds)

#### Package Options

- `flutter_blue_plus`: Most mature Flutter BLE package
- `flutter_reactive_ble`: Performance-focused alternative
- Custom platform channels: Maximum control

#### Decision Status

**✅ Recommended for Phase 1 (MVP)**

---

### Option 2: iOS MultipeerConnectivity

#### Overview

Apple's purpose-built framework for local peer discovery and communication.

#### Technical Details

- **Transport**: Automatic selection (WiFi, Bluetooth, WiFi infrastructure)
- **Range**: 30+ feet (better than BLE alone)
- **Connections**: Supports 8+ devices easily
- **Bandwidth**: High (uses WiFi when available)
- **iOS Only**: Not available on Android

#### Implementation Approach

```swift
// iOS native code via platform channel
MCNearbyServiceAdvertiser  // Team leader advertises session
MCNearbyServiceBrowser      // Players discover sessions
MCSession                   // Data transmission
MCPeerID                    // Device identification
```

#### Pros

- ✅ Purpose-built for local multiplayer
- ✅ Automatic transport selection (BLE/WiFi)
- ✅ Seamless network transitions
- ✅ Apple's recommended approach
- ✅ Excellent reliability
- ✅ Simple session-based API
- ✅ Works well in background

#### Cons

- ❌ iOS only (requires separate Android implementation)
- ❌ Requires Swift/Objective-C native code
- ❌ More complex architecture (platform-specific)
- ❌ Testing requires iOS devices

#### Decision Status

**🔄 Phase 2 Enhancement for iOS**

---

### Option 3: Android Nearby Connections API

#### Overview

Google's framework for high-bandwidth peer-to-peer connectivity.

#### Technical Details

- **Transport**: Automatic (BLE, WiFi Direct, WiFi LAN)
- **Range**: 30+ feet (better than BLE alone)
- **Connections**: Supports 8+ devices easily
- **Bandwidth**: High (uses WiFi when available)
- **Android Only**: Requires Google Play Services

#### Implementation Approach

```kotlin
// Android native code via platform channel
Nearby.getConnectionsClient()    // Get connections client
startAdvertising()                // Team leader advertises
startDiscovery()                  // Players discover
requestConnection()               // Establish connection
sendPayload()                     // Send messages
```

#### Pros

- ✅ Purpose-built for P2P
- ✅ Automatic transport selection
- ✅ Google's recommended approach
- ✅ Excellent reliability
- ✅ Handles larger groups well
- ✅ High bandwidth

#### Cons

- ❌ Android only (requires separate iOS implementation)
- ❌ Requires Kotlin/Java native code
- ❌ Requires Google Play Services (not universal)
- ❌ More complex architecture (platform-specific)
- ❌ Testing requires Android devices

#### Decision Status

**🔄 Phase 2 Enhancement for Android**

---

### Option 4: Hybrid/Composite Approach

#### Overview

Use platform-specific implementations with BLE fallback.

#### Architecture

```
P2PServiceComposite (tries implementations in order)
├── iOS: P2PServiceMultipeer (primary)
│   └── Fallback: P2PServiceBLE
└── Android: P2PServiceNearby (primary)
    └── Fallback: P2PServiceBLE
```

#### Pros

- ✅ Best reliability (multiple transports)
- ✅ Optimal performance per platform
- ✅ Graceful degradation
- ✅ Future-proof (can add new transports)
- ✅ Platform-native experience

#### Cons

- ❌ Most complex implementation
- ❌ Three separate codebases to maintain
- ❌ More testing required (iOS, Android, BLE)
- ❌ Longer development time
- ❌ Larger app size

#### Decision Status

**🔮 Future Goal (Phase 3)**

---

## Implementation Phases

### Phase 1: MVP - BLE Only (CURRENT DECISION)

**Timeline**: Weeks 1-4

**Scope**:

- Implement `P2PServiceBLE` with full functionality
- Team leader as GATT server
- Players as GATT clients
- Session discovery via BLE advertising
- Turn notifications via BLE characteristics
- Time tracking and synchronization

**Deliverables**:

```
lib/services/
├── p2p_service.dart           # Abstract interface
├── p2p_service_ble.dart       # BLE implementation
├── p2p_service_stub.dart      # Development/testing stub
└── p2p_exceptions.dart        # Custom exceptions
```

**Testing**:

- Unit tests with stub implementation
- Widget tests with mock service
- Integration tests with 2+ physical devices
- Stress test with 8 devices

**Success Criteria**:

- ✅ 8 devices connect successfully
- ✅ < 2 second turn notification delivery
- ✅ < 30 second setup time
- ✅ 4+ hour battery life
- ✅ Works at 10-foot range
- ✅ 95%+ successful session completion

---

### Phase 2: Platform Enhancements (IF NEEDED)

**Timeline**: Weeks 5-8 (only if Phase 1 shows issues)

**Trigger Conditions**:

- Connection reliability < 95%
- Range issues at 10+ feet
- Excessive battery drain
- Poor performance in crowded RF environments
- User feedback indicates problems

**Scope**:

- Implement `P2PServiceMultipeer` for iOS
- Implement `P2PServiceNearby` for Android
- Implement `P2PServiceComposite` for automatic selection
- Update factory to use platform-specific implementations

**Deliverables**:

```
lib/services/
├── p2p_service_multipeer.dart     # iOS implementation
├── p2p_service_nearby.dart        # Android implementation
├── p2p_service_composite.dart     # Fallback chain
└── p2p_service_factory.dart       # Updated factory

ios/Runner/
└── P2PBridge.swift                # MultipeerConnectivity bridge

android/app/src/main/kotlin/
└── P2PBridge.kt                   # Nearby Connections bridge
```

**Testing**:

- All Phase 1 tests
- Platform-specific integration tests
- Fallback mechanism tests
- Cross-platform sessions (iOS + Android)

---

### Phase 3: Advanced Features (FUTURE)

**Scope** (as needed based on user feedback):

- Connection resilience improvements
- Player reconnection logic
- Network health monitoring
- Connection quality indicators
- Alternative transports (NFC, ultrasonic, etc.)
- Mesh networking for 8+ players

---

## Message Protocol Design

### Message Types

```dart
enum MessageType {
  sessionInfo,      // Session metadata
  joinRequest,      // Player wants to join
  joinAccept,       // Player accepted into session
  joinReject,       // Player rejected (session full/started)
  turnChange,       // Turn passed to next player
  timerUpdate,      // Timer value changed
  playerList,       // Updated player list/order
  gameEnd,          // Game ended by leader
  gamePause,        // Game paused by leader
  gameResume,       // Game resumed by leader
  ping,            // Connection health check
  pong,            // Ping response
}
```

### Message Format

```dart
class P2PMessage {
  final String messageId;         // UUID for deduplication
  final MessageType type;         // Message type
  final String sessionId;         // Session identifier
  final String senderId;          // Sending device ID
  final DateTime timestamp;       // Send time
  final Map<String, dynamic> data; // Type-specific payload
  
  // Serialize to JSON for transmission
  String toJson();
  
  // Deserialize from received data
  factory P2PMessage.fromJson(String json);
}
```

### Message Size Constraints

- **BLE Limit**: 512 bytes per characteristic write
- **Target**: Keep all messages < 256 bytes
- **Strategy**: Use compact JSON, abbreviate field names if needed

### Example Messages

```json
// Turn change notification
{
  "id": "a1b2c3",
  "type": "turnChange",
  "session": "s-12345",
  "sender": "d-leader",
  "time": "2026-02-01T10:30:00Z",
  "data": {
    "nextPlayer": "d-player2",
    "turnIndex": 3,
    "timerSeconds": 300
  }
}

// Join request
{
  "id": "x7y8z9",
  "type": "joinRequest",
  "session": "s-12345",
  "sender": "d-player3",
  "time": "2026-02-01T10:25:00Z",
  "data": {
    "playerName": "Alice",
    "deviceInfo": "iPhone 14 Pro"
  }
}
```

---

## Connection State Management

### State Machine

```
[Disconnected] --initialize--> [Initialized]
[Initialized] --discover--> [Discovering]
[Discovering] --found--> [Connecting]
[Connecting] --success--> [Connected]
[Connecting] --failed--> [Disconnected]
[Connected] --disconnect--> [Disconnected]
[Connected] --error--> [Error]
[Error] --reconnect--> [Connecting]
```

### State Tracking

```dart
enum ConnectionState {
  disconnected,   // No connection
  initialized,    // Service ready
  discovering,    // Scanning for sessions
  connecting,     // Establishing connection
  connected,      // Active connection
  error,         // Connection error
}

class ConnectionStatus {
  final ConnectionState state;
  final String? sessionId;
  final List<ConnectedPlayer> players;
  final String? errorMessage;
  final DateTime lastUpdate;
}
```

---

## Error Handling Strategy

### Error Categories

1. **Discovery Errors**
   - Bluetooth disabled
   - Location permission denied (Android)
   - No sessions found
   - Discovery timeout

2. **Connection Errors**
   - Connection timeout
   - Device out of range
   - Connection refused
   - Session full
   - Session already started

3. **Communication Errors**
   - Message send failed
   - Message too large
   - Invalid message format
   - Sequence number mismatch

4. **Session Errors**
   - Leader disconnected
   - Player disconnected
   - Session ended
   - State synchronization failure

### Error Recovery

```dart
class P2PErrorHandler {
  /// Handles error with automatic recovery attempts
  Future<void> handleError(P2PException error) async {
    switch (error.type) {
      case ErrorType.connectionLost:
        // Attempt reconnection
        await _retryConnection(maxAttempts: 3);
        break;
        
      case ErrorType.messageFailed:
        // Retry message send
        await _retryMessage(error.message, maxAttempts: 2);
        break;
        
      case ErrorType.leaderDisconnected:
        // End game for all players
        await _endGameGracefully();
        break;
        
      case ErrorType.bluetooth Disabled:
        // Show user prompt to enable Bluetooth
        _showBluetoothPrompt();
        break;
    }
  }
}
```

---

## Security Considerations

### Current Implementation (Phase 1)

⚠️ **Minimal security** - local network only, ephemeral sessions

**Assumptions**:

- Players are physically co-located (same table)
- No sensitive data transmitted
- Sessions are temporary (game duration only)
- Low risk of malicious actors in gaming environment

### Potential Vulnerabilities

1. **Session Hijacking**: Anyone within range could discover and join
2. **Message Spoofing**: No authentication of messages
3. **Man-in-the-Middle**: Messages not encrypted
4. **Denial of Service**: Malicious device could flood messages

### Future Security Enhancements (Phase 2+)

1. **Session Passwords**: Optional PIN for joining
2. **Message Signing**: Cryptographic signatures for messages
3. **Encryption**: AES encryption for message payloads
4. **Device Authentication**: Verify device identity
5. **Rate Limiting**: Prevent message flooding

---

## Performance Optimization

### Connection Optimization

- **Fast Advertising**: Reduce BLE advertising interval for quick discovery
- **Aggressive Scanning**: High-duty-cycle scanning during discovery phase
- **Connection Caching**: Remember previously connected devices
- **Lazy Disconnection**: Keep connections alive between turns

### Message Optimization

- **Message Batching**: Combine multiple updates when possible
- **Compression**: GZIP small payloads if beneficial
- **Deduplication**: Track message IDs to prevent duplicate processing
- **Priority Queue**: Send critical messages (turn changes) first

### Battery Optimization

- **Adaptive Scanning**: Reduce scan rate when not discovering
- **Connection Pooling**: Reuse connections efficiently
- **Background Throttling**: Reduce activity when app backgrounded
- **Wake Lock Management**: Only prevent sleep during active turns

---

## Testing Strategy

### Unit Tests

```dart
test('P2PService initialization succeeds', () async {
  final service = P2PServiceStub();
  final result = await service.initialize();
  expect(result, true);
});

test('Message serialization round-trip', () {
  final original = P2PMessage(/* ... */);
  final json = original.toJson();
  final decoded = P2PMessage.fromJson(json);
  expect(decoded, equals(original));
});
```

### Integration Tests

- 2-device session creation and joining
- 4-device turn rotation
- 8-device stress test
- Connection loss and recovery
- Leader disconnection handling
- Message delivery verification

### Field Testing

- Gaming store environment (RF interference)
- Home environment (minimal interference)
- Large table (10+ foot range)
- Mixed iOS/Android devices
- Extended sessions (4+ hours)

---

## Platform-Specific Implementation Notes

### iOS Considerations

**Permissions Required**:

```xml
<!-- Info.plist -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>YourTurn needs Bluetooth to connect with nearby players for turn tracking</string>

<key>NSLocalNetworkUsageDescription</key>
<string>YourTurn uses local network to discover nearby game sessions</string>
```

**Background Modes**:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>bluetooth-central</string>
  <string>bluetooth-peripheral</string>
</array>
```

**Implementation Notes**:

- Use `CBCentralManager` for BLE central role
- Use `CBPeripheralManager` for BLE peripheral role
- Request `CBManagerAuthorization` at app launch
- Handle state changes in `centralManagerDidUpdateState`
- Keep screen awake to avoid BLE background restrictions

### Android Considerations

**Permissions Required**:

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**Runtime Permissions** (Android 6.0+):

- Request location permissions (required for BLE scanning)
- Request Bluetooth permissions (Android 12+)
- Handle permission denial gracefully

**Implementation Notes**:

- Use `BluetoothLeAdvertiser` for advertising
- Use `BluetoothLeScanner` for discovery
- Use `BluetoothGattServer` for team leader
- Use `BluetoothGatt` for players
- Handle Android BLE stack quirks (varies by manufacturer)

---

## Open Questions & Decisions Needed

### Technical Decisions

- [x] **Primary Technology**: BLE for Phase 1
- [x] **Architecture**: Abstract service with swappable implementations
- [x] **Platform-specific P2P**: MultipeerConnectivity (iOS) and Nearby Connections (Android) implemented
- [x] **QR Code Fallback**: Implemented for discovery using `qr_flutter` and `mobile_scanner`
- [ ] **BLE Package**: flutter_blue_plus vs flutter_reactive_ble vs custom
- [ ] **Service UUID**: Define custom UUID for YourTurn GATT service
- [ ] **Characteristic UUIDs**: Define for session info, notifications, messages
- [ ] **Message Format**: JSON vs Protocol Buffers vs custom binary
- [ ] **Connection Timeout**: How long to wait for connection establishment?
- [ ] **Reconnection Policy**: How many retries? What intervals?
- [ ] **Cross-Platform Solution**: See Open Discussion section below

### Design Decisions

- [x] **Session Discovery UI**: Nearby Sessions list with host name and status
- [x] **QR Code Display**: Setup screen shows scannable QR code for session
- [ ] **Connection Status**: How to show connection quality to users?
- [ ] **Error Messages**: What to tell users when connections fail?
- [ ] **Leader Indicator**: How to distinguish team leader in session list?

### Testing Decisions

- [ ] **Device Requirements**: What iOS/Android versions to test?
- [ ] **Test Scenarios**: What are the critical paths to validate?
- [ ] **Performance Metrics**: What thresholds for success?

---

## 🔴 OPEN DISCUSSION: Cross-Platform Connectivity Decision

### The Core Question

**How should YourTurn handle mixed iOS + Android gaming groups?**

The current platform-specific implementations (MultipeerConnectivity on iOS, Nearby Connections on Android) work excellently within their own ecosystems but cannot interoperate. We need to decide on a strategy for cross-platform connectivity.

### Option 1: Bluetooth Low Energy (BLE) - Universal Protocol

**Approach**: Implement BLE GATT server/client that works identically on both platforms.

```
iOS Device (GATT Server) ←→ Android Device (GATT Client)
Android Device (GATT Server) ←→ iOS Device (GATT Client)
```

| Aspect | Details |
| ------ | ------- |
| **Pros** | True cross-platform, no server needed, no WiFi required, battery efficient |
| **Cons** | Complex GATT implementation, 7-8 device limit, slower connection setup (5-10s), platform BLE stack differences |
| **Complexity** | High - requires native code on both platforms |
| **Dependencies** | `flutter_blue_plus` or custom platform channels |
| **Internet Required** | No |

**Implementation Notes**:
- Team leader runs GATT server advertising session UUID
- Players scan for GATT services and connect as clients
- Use characteristics for: session info (read), turn notifications (notify), player messages (write)
- Must handle iOS background BLE restrictions

### Option 2: Local WiFi (TCP/IP Sockets)

**Approach**: Use standard TCP/IP sockets when devices are on the same WiFi network.

```
Host Device (TCP Server on port XXXX)
    ↑
    └── All devices connect via local IP address
```

| Aspect | Details |
| ------ | ------- |
| **Pros** | Fast, reliable, high bandwidth, simple protocol, works cross-platform |
| **Cons** | Requires same WiFi network, discovery requires mDNS/Bonjour or manual IP entry |
| **Complexity** | Medium - standard socket programming |
| **Dependencies** | None (Dart `dart:io` sockets) |
| **Internet Required** | No (local network only) |

**Implementation Notes**:
- Host creates TCP server on ephemeral port
- Use mDNS/Bonjour for service discovery (or QR code with IP:port)
- JSON messages over TCP
- Works great for home/cafe with shared WiFi
- Fails in venues without WiFi or with client isolation

### Option 3: WebSocket Server (Cloud-Based)

**Approach**: All devices connect to a central WebSocket server that relays messages.

```
Cloud Server (WebSocket)
    ↑
    ├── iOS Device 1
    ├── iOS Device 2
    ├── Android Device 1
    └── Android Device 2
```

| Aspect | Details |
| ------ | ------- |
| **Pros** | Simple client implementation, works anywhere with internet, no P2P complexity |
| **Cons** | Requires internet, requires hosting/maintaining server, latency depends on connection |
| **Complexity** | Low (client) / Medium (server) |
| **Dependencies** | `web_socket_channel`, server infrastructure |
| **Internet Required** | Yes |

**Server Options**:
- Self-hosted (Node.js, Go, etc.) - full control, hosting costs
- Firebase Realtime Database - managed, easy setup, Google dependency
- Supabase Realtime - managed, open source friendly
- AWS API Gateway WebSocket - scalable, pay-per-use

### Option 4: Hybrid Approach (Recommended for Discussion)

**Approach**: Use the best technology available based on the situation.

```
Same Platform?
├── Yes → Use native P2P (MultipeerConnectivity / Nearby Connections)
└── No → Mixed group detected
         └── Same WiFi?
             ├── Yes → Use Local TCP/IP
             └── No → Use BLE (or cloud fallback)
```

| Aspect | Details |
| ------ | ------- |
| **Pros** | Best experience for each scenario, graceful degradation |
| **Cons** | Most complex to implement, more code paths to test |
| **Complexity** | High |
| **Dependencies** | Multiple |
| **Internet Required** | Optional (for cloud fallback) |

### Option 5: Accept Platform Limitation

**Approach**: Document that cross-platform groups need all-iOS or all-Android. Rely on QR codes for easy session sharing within same platform.

| Aspect | Details |
| ------ | ------- |
| **Pros** | No additional development, current implementation works well |
| **Cons** | Poor UX for mixed groups, limits market appeal |
| **Complexity** | None (already done) |
| **Dependencies** | Current implementation |
| **Internet Required** | No |

### Decision Criteria

Consider these factors when making the decision:

1. **Target User Base**: How common are mixed iOS/Android gaming groups?
2. **Development Resources**: How much time/effort can be allocated?
3. **Deployment Constraints**: Can we require internet? Same WiFi?
4. **Long-term Maintenance**: What's sustainable to maintain?
5. **User Experience**: What's acceptable friction for setup?

### Recommendation

**For MVP**: Option 5 (Accept Limitation) with QR codes for easy same-platform joining.

**For v1.1**: Option 2 (Local WiFi) as the first cross-platform solution - it's the simplest to implement and covers the common case of friends gaming at home or a cafe.

**For v2.0**: Option 4 (Hybrid) with BLE as the universal fallback for venues without shared WiFi.

### Action Items

- [ ] **Decide**: Which option(s) to pursue and in what order
- [ ] **User Research**: Survey target users about iOS/Android mix in their groups
- [ ] **Prototype**: Build proof-of-concept for chosen approach
- [ ] **Test**: Validate in real gaming scenarios

---

## References & Resources

### BLE Resources

- [Bluetooth Core Specification](https://www.bluetooth.com/specifications/specs/)
- [GATT Services](https://www.bluetooth.com/specifications/gatt/services/)
- [Flutter Blue Plus Documentation](https://pub.dev/packages/flutter_blue_plus)
- [iOS Core Bluetooth Guide](https://developer.apple.com/documentation/corebluetooth)
- [Android BLE Guide](https://developer.android.com/guide/topics/connectivity/bluetooth-le)

### Platform-Specific Resources

- [iOS MultipeerConnectivity](https://developer.apple.com/documentation/multipeerconnectivity)
- [Android Nearby Connections](https://developers.google.com/nearby/connections/overview)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)

### Related Documentation

- [Architecture Guidelines](../,github/copilot-instructions-architecture.md)
- [Connectivity Guidelines](../.github/copilot-instructions-connectivity.md)
- [Requirements Document](requirements.md)
- [Testing Guidelines](../.github/copilot-instructions-testing.md)

---

## Revision History

| Version | Date       | Author | Changes                          |
|---------|------------|--------|----------------------------------|
| 1.0     | 2026-02-01 | Team   | Initial design document          |
| 1.1     | 2026-02-02 | Team   | Added cross-platform interoperability section, QR code implementation details, open discussion for connectivity decision |
| 2.0     | TBD        |        | Phase 2 platform enhancements    |

---

*This document is a living design document and should be updated as implementation progresses and new decisions are made. All significant changes should be recorded in the revision history.*
