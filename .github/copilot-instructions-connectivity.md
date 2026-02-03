# Connectivity Guidelines for YourTurn

## Overview

YourTurn requires local peer-to-peer (P2P) networking to enable turn notifications between devices playing the same tabletop game. This is a **critical and complex** component that enables the core functionality of the app.

## ⚠️ Critical: Same WiFi Network Requirement

> **All devices must be connected to the same WiFi network to use YourTurn.**
>
> This is a temporary requirement for cross-platform (iOS + Android) support. While not the preferred long-term solution, it provides the simplest and most reliable connectivity for mixed platform groups. Future versions may support direct P2P without this dependency.

**Why this approach?**

- Simplest cross-platform solution available
- Works reliably in most gaming scenarios (home, cafe, game store)
- No complex BLE GATT implementation required
- Standard TCP/IP sockets work identically on iOS and Android

**Limitations:**

- Requires WiFi network infrastructure
- Won't work outdoors without mobile hotspot
- Some public networks have client isolation

## Cross-Platform Limitation (Background)

**iOS and Android native P2P protocols DO NOT interoperate:**

- **iOS**: Uses MultipeerConnectivity (Apple proprietary)
- **Android**: Uses Nearby Connections (Google Play Services)

These protocols cannot discover or communicate with each other. This means:

- ✅ iOS-to-iOS works via MultipeerConnectivity
- ✅ Android-to-Android works via Nearby Connections
- ✅ iOS-to-Android works via same WiFi network (current solution)

**Current Implementation:**

1. Same WiFi network required for cross-platform sessions
2. QR codes for session discovery (implemented)
3. Manual session code entry (implemented)

**For direct P2P without WiFi (future), BLE GATT implementation would be needed** - see the "Cross-Platform Options" section below.

## Current Implementation Status

### P2P Services

| Service | File | Technology | Cross-Platform? | Status |
|---------|------|------------|-----------------|--------|
| **WiFi (Default)** | `lib/services/p2p_service_wifi.dart` | TCP/IP Sockets + UDP Discovery | ✅ Yes | ✅ Implemented |
| iOS Native | `lib/services/p2p_service_ios.dart` | MultipeerConnectivity | ❌ iOS only | ✅ Implemented |
| Android Native | `lib/services/p2p_service_android.dart` | Nearby Connections | ❌ Android only | ✅ Implemented |
| Stub | `lib/services/p2p_service_stub.dart` | In-Memory | N/A | ✅ Implemented |

### Factory Configuration

The P2P service factory (`p2p_service_factory.dart`) supports three modes:

```dart
// WiFi mode (default) - cross-platform, requires same WiFi network
P2PService createP2PService(mode: P2PMode.wifi);

// Platform-native mode - better performance but NOT cross-platform
P2PService createP2PService(mode: P2PMode.platformNative);

// Stub mode - for testing/development
P2PService createP2PService(mode: P2PMode.stub);
```

**Default mode is WiFi** for cross-platform support.

### QR Code Support (Discovery Fallback)

- **Generation**: `qr_flutter` package - displays `yourturn:{sessionCode}` on setup screen
- **Scanning**: `mobile_scanner` package - scans and auto-joins sessions
- **Note**: QR codes help with discovery but don't solve cross-platform communication

## P2P Architecture

### Network Topology

```text
Device A (Host)
    │
    ├── Device B (Player)
    ├── Device C (Player)
    └── Device D (Player)

Star Topology:
- 1 Host device creates and advertises the session
- Player devices discover and connect to host
- All messages flow through the host
- Host broadcasts turn changes to all players
```

### Connection Types

#### Current: Platform-Native P2P

**iOS - MultipeerConnectivity:**

- Automatic transport selection (WiFi, Bluetooth, infrastructure)
- Excellent reliability and range (30+ feet)
- Apple's recommended approach
- iOS-only

**Android - Nearby Connections:**

- Automatic transport selection (BLE, WiFi Direct, WiFi LAN)
- High bandwidth and reliability
- Google's recommended approach
- Requires Google Play Services

#### Future: Cross-Platform Options

**Option 1: Bluetooth Low Energy (BLE)**

- Universal standard supported on both platforms
- True cross-platform without server
- Complex GATT implementation required
- 7-8 device connection limit

**Option 2: Local WiFi (TCP/IP Sockets)**

- Works when devices share same WiFi network
- Simple implementation with Dart sockets
- Requires mDNS for discovery or manual IP entry
- Fails with client isolation or no WiFi

**Option 3: Cloud Server (WebSocket)**

- Works anywhere with internet
- Simple client implementation
- Requires hosting and internet connectivity
- Adds latency

### Recommended Approach for Cross-Platform

For mixed iOS/Android groups, implement in this order:

1. **Phase 1 (Current)**: Same-platform native P2P + QR code discovery
2. **Phase 2**: Local WiFi TCP/IP for same-network groups
3. **Phase 3**: BLE for offline cross-platform support

## Service Architecture

### P2PService Interface

```dart
/// Abstract interface for P2P communication
abstract class P2PService {
  /// Initialize the P2P service
  /// Must be called before any other operations
  Future<bool> initialize();
  
  /// Start discovering nearby devices
  /// Returns a stream of discovered devices
  Stream<Device> startDiscovery();
  
  /// Stop discovering devices
  Future<void> stopDiscovery();
  
  /// Create a session (become host)
  /// Returns session identifier
  Future<String> createSession(String sessionName);
  
  /// Join an existing session
  /// Connects to the specified session
  Future<bool> joinSession(String sessionId);
  
  /// Leave the current session
  Future<void> leaveSession();
  
  /// Send turn notification to all connected devices
  Future<void> sendTurnNotification(TurnData turnData);
  
  /// Listen for incoming turn notifications
  Stream<TurnData> listenForTurnNotifications();
  
  /// Get list of connected devices
  List<Device> getConnectedDevices();
  
  /// Dispose and cleanup resources
  Future<void> dispose();
}
```

### Platform Implementations

#### Android (Nearby Connections)

**Dart Location**: `lib/services/p2p_service_android.dart`
**Native Location**: `android/app/src/main/kotlin/.../P2PHandler.kt`

**Key Technologies**:

- Google Nearby Connections API (P2P_STAR strategy)
- MethodChannel for Flutter communication
- EventChannel for streaming events

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
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />
```

**Implementation Notes**:

- Uses `P2P_STAR` strategy for advertising and discovery
- Session creator advertises with session code in endpoint info
- Players discover and request connection to advertised sessions
- JSON messages broadcast to all connected endpoints
- Handles connection lifecycle callbacks

#### iOS (MultipeerConnectivity)

**Dart Location**: `lib/services/p2p_service_ios.dart`
**Native Location**: `ios/Runner/P2PHandler.swift`

**Key Technologies**:

- MultipeerConnectivity framework
- MCNearbyServiceAdvertiser for session hosting
- MCNearbyServiceBrowser for session discovery
- MCSession for data transmission
- FlutterMethodChannel for communication

**Permissions Required**:

```xml
<!-- Info.plist -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>YourTurn needs Bluetooth to connect with nearby players</string>
<key>NSLocalNetworkUsageDescription</key>
<string>YourTurn needs local network access to discover nearby game sessions</string>
<key>NSBonjourServices</key>
<array>
  <string>_yourturn._tcp</string>
</array>
```

**Implementation Notes**:

- Service type: `yourturn` (advertised via Bonjour)
- Session info embedded in discovery info dictionary
- Automatic invitation handling for joining players
- JSON messages sent via MCSession data transmission
- Handles peer state changes and disconnections

#### Stub Implementation (In-Memory)

**Location**: `lib/services/p2p_service_stub.dart`

**Purpose**: Development and testing without physical devices

```dart
class InMemoryP2PService implements P2PService {
  // Singleton pattern for in-memory session sharing
  static final _sessions = <String, Session>{};

  // Used on non-mobile platforms (web, desktop, simulator)
  // Allows testing the full app flow without native P2P
}
```

#### Service Factory

**Location**: `lib/services/p2p_service_factory.dart`

```dart
class P2PServiceFactory {
  static P2PService create() {
    if (Platform.isIOS) {
      return IosP2PService();      // MultipeerConnectivity
    } else if (Platform.isAndroid) {
      return AndroidP2PService();  // Nearby Connections
    } else {
      return InMemoryP2PService(); // Stub for testing
    }
  }
}
```

## Data Protocol

### Message Format

```dart
class TurnData {
  final String sessionId;
  final String playerId;
  final int turnIndex;
  final DateTime timestamp;
  final MessageType type;
  
  // Serialize for transmission
  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'playerId': playerId,
    'turnIndex': turnIndex,
    'timestamp': timestamp.toIso8601String(),
    'type': type.toString(),
  };
  
  // Deserialize from received data
  factory TurnData.fromJson(Map<String, dynamic> json) {
    return TurnData(
      sessionId: json['sessionId'],
      playerId: json['playerId'],
      turnIndex: json['turnIndex'],
      timestamp: DateTime.parse(json['timestamp']),
      type: MessageType.values.firstWhere(
        (e) => e.toString() == json['type']
      ),
    );
  }
}

enum MessageType {
  turnChange,      // Next player's turn
  playerJoined,    // New player joined session
  playerLeft,      // Player left session
  sessionEnd,      // Session ended
  ping,           // Keep-alive
  pong,           // Keep-alive response
}
```

### Message Size Limits

- **BLE**: Maximum ~512 bytes per characteristic
- **WiFi**: Practically unlimited, keep messages < 64KB
- **Recommendation**: Keep all messages < 512 bytes for BLE compatibility

### Encryption

```dart
// TODO: Implement message encryption for security
// Use symmetric encryption (AES) with session key
// Exchange keys during session join using public key crypto
```

## Connection Management

### Session Lifecycle

#### 1. Create Session (Host)

```dart
Future<String> createSession(String playerName) async {
  // 1. Generate session ID
  final sessionId = Uuid().v4();
  
  // 2. Initialize BLE advertising
  await _startAdvertising(sessionId);
  
  // 3. Start accepting connections
  await _startServer();
  
  // 4. Create local session state
  _currentSession = Session(
    id: sessionId,
    hostId: _localDeviceId,
    players: [Player(id: _localDeviceId, name: playerName)],
  );
  
  return sessionId;
}
```

#### 2. Join Session (Player)

```dart
Future<bool> joinSession(String sessionId, String playerName) async {
  // 1. Discover host device
  final host = await _discoverHost(sessionId);
  if (host == null) return false;
  
  // 2. Connect to host
  final connected = await _connectToHost(host);
  if (!connected) return false;
  
  // 3. Send join request
  final joinRequest = JoinRequest(
    playerId: _localDeviceId,
    playerName: playerName,
  );
  await _sendMessage(host, joinRequest);
  
  // 4. Wait for acceptance
  final accepted = await _waitForJoinAcceptance();
  return accepted;
}
```

#### 3. Send Turn Notification

```dart
Future<void> sendTurnNotification(int nextTurnIndex) async {
  final turnData = TurnData(
    sessionId: _currentSession.id,
    playerId: _localDeviceId,
    turnIndex: nextTurnIndex,
    timestamp: DateTime.now(),
    type: MessageType.turnChange,
  );
  
  // Send to all connected devices
  for (final device in _connectedDevices) {
    await _sendMessage(device, turnData);
  }
}
```

#### 4. Leave Session

```dart
Future<void> leaveSession() async {
  if (_isHost) {
    // Host: Notify all players and end session
    await _sendSessionEnd();
    await _stopAdvertising();
    await _stopServer();
  } else {
    // Player: Disconnect and notify host
    await _sendLeaveNotification();
    await _disconnect();
  }
  
  _currentSession = null;
  _connectedDevices.clear();
}
```

### Connection States

```dart
enum ConnectionState {
  disconnected,    // No connection
  discovering,     // Searching for devices
  connecting,      // Attempting connection
  connected,       // Active connection
  disconnecting,   // Closing connection
  error,          // Connection error
}
```

### State Management

```dart
class ConnectionStateManager extends ChangeNotifier {
  ConnectionState _state = ConnectionState.disconnected;
  String? _errorMessage;
  
  ConnectionState get state => _state;
  String? get errorMessage => _errorMessage;
  
  void setState(ConnectionState newState, [String? error]) {
    _state = newState;
    _errorMessage = error;
    notifyListeners();
  }
}
```

## Error Handling

### Common Errors

#### Discovery Errors

```dart
class DiscoveryException implements Exception {
  final String message;
  DiscoveryException(this.message);
  
  // Common cases:
  // - Bluetooth disabled
  // - Location permission denied
  // - No devices found
  // - Timeout
}
```

#### Connection Errors

```dart
class ConnectionException implements Exception {
  final String message;
  final Device? device;
  ConnectionException(this.message, [this.device]);
  
  // Common cases:
  // - Connection timeout
  // - Device out of range
  // - Connection refused
  // - Connection dropped
}
```

#### Message Errors

```dart
class MessageException implements Exception {
  final String message;
  MessageException(this.message);
  
  // Common cases:
  // - Message too large
  // - Invalid format
  // - Encryption error
  // - Send failed
}
```

### Retry Logic

```dart
Future<T> retryOperation<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration delayBetween = const Duration(seconds: 1),
}) async {
  int attempts = 0;
  
  while (attempts < maxAttempts) {
    try {
      return await operation();
    } catch (e) {
      attempts++;
      if (attempts >= maxAttempts) rethrow;
      await Future.delayed(delayBetween);
    }
  }
  
  throw Exception('Max retry attempts exceeded');
}
```

### Connection Health Monitoring

```dart
// Periodic ping to verify connection
Timer? _healthCheckTimer;

void startHealthCheck() {
  _healthCheckTimer = Timer.periodic(
    Duration(seconds: 10),
    (_) => _checkConnectionHealth(),
  );
}

Future<void> _checkConnectionHealth() async {
  for (final device in _connectedDevices) {
    try {
      await _sendPing(device);
      final pong = await _waitForPong(device, timeout: Duration(seconds: 5));
      if (pong == null) {
        // Connection dead, remove device
        _handleDeviceDisconnected(device);
      }
    } catch (e) {
      _handleDeviceDisconnected(device);
    }
  }
}
```

## Testing Strategy

### Unit Tests

- Test P2PService interface with mocks
- Test message serialization/deserialization
- Test state management
- Test error handling

### Integration Tests

- Test device discovery (requires real devices)
- Test connection establishment
- Test message transmission
- Test connection recovery
- Test session lifecycle

### Platform Tests

- Test on various Android versions
- Test on various iOS versions
- Test with different device manufacturers
- Test in various environments (interference, distance)

### Test Scenarios

1. **Happy Path**: Create session, join session, send turns
2. **Connection Loss**: Handle device going out of range
3. **Host Leaves**: Transfer host role or end session
4. **Multiple Players**: Test with maximum supported devices
5. **Rapid Turn Changes**: Stress test message throughput
6. **Background/Foreground**: Test app lifecycle transitions

## Performance Considerations

### Optimization Guidelines

- Minimize message frequency (debounce rapid changes)
- Batch multiple updates when possible
- Use efficient serialization (protobuf or msgpack)
- Limit connection attempts to avoid battery drain
- Stop discovery when not needed
- Cache device information

### Battery Impact

- BLE scanning is battery intensive - limit duration
- Use low-power BLE mode when possible
- Stop advertising when session is full
- Disconnect idle connections after timeout

### Scalability

- Recommended: 2-8 players
- Maximum tested: TBD
- Consider fallback to star topology for larger groups

## Security Considerations

### Current Implementation

⚠️ **WARNING**: Initial version has minimal security

- No encryption of messages
- No authentication of devices
- Session IDs are UUIDs (predictable)

### Future Enhancements

- [ ] Implement end-to-end encryption
- [ ] Add device authentication
- [ ] Use cryptographic session IDs
- [ ] Add session passwords/PINs
- [ ] Implement man-in-the-middle protection

### Privacy

- Keep all data local (no cloud transmission)
- Don't store persistent device identifiers
- Clear session data when app closes

## Debugging Tools

### Logging

```dart
// Enable verbose P2P logging
const bool _debugP2P = true;

void _logP2P(String message) {
  if (_debugP2P) {
    print('[P2P] $message');
  }
}
```

### Connection Inspector

```dart
// Widget to display connection status
class P2PDebugPanel extends StatelessWidget {
  final P2PService service;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text('Session: ${service.currentSession?.id ?? "None"}'),
          Text('State: ${service.connectionState}'),
          Text('Devices: ${service.connectedDevices.length}'),
          ...service.connectedDevices.map((d) => 
            ListTile(title: Text(d.name), subtitle: Text(d.id))
          ),
        ],
      ),
    );
  }
}
```

## Cross-Platform Connectivity Options

When implementing cross-platform support (iOS + Android in same session), consider these approaches:

### Option 1: Bluetooth Low Energy (BLE)

```dart
// Conceptual approach
class P2PServiceBLE implements P2PService {
  // Team leader runs GATT server
  // Players connect as GATT clients
  // Works cross-platform but complex to implement
}
```

Pros: No WiFi needed, true offline P2P
Cons: Complex GATT implementation, 7-8 device limit, platform quirks

### Option 2: Local WiFi TCP/IP

```dart
// Conceptual approach
class P2PServiceTCP implements P2PService {
  // Host creates TCP server on local IP
  // Players connect via IP:port (from QR code or mDNS)
  // Simple socket-based communication
}
```

Pros: Simple, fast, reliable
Cons: Requires same WiFi network, fails with client isolation

### Option 3: WebSocket Server

```dart
// Conceptual approach
class P2PServiceCloud implements P2PService {
  // All devices connect to central WebSocket server
  // Server relays messages between session members
  // Works anywhere with internet
}
```

Pros: Works anywhere, simple client code
Cons: Requires internet, server hosting/costs

### Recommended Implementation Order

1. **Now**: Platform-native P2P (implemented) + QR codes for discovery
2. **Next**: Local WiFi TCP/IP for same-network cross-platform
3. **Future**: BLE for offline cross-platform scenarios

See `docs/connectivity-design.md` for detailed analysis and decision criteria.

## Resources

- [Android Nearby Connections](https://developers.google.com/nearby/connections/overview)
- [iOS MultipeerConnectivity](https://developer.apple.com/documentation/multipeerconnectivity)
- [Android BLE Guide](https://developer.android.com/guide/topics/connectivity/bluetooth-le)
- [iOS Core Bluetooth](https://developer.apple.com/documentation/corebluetooth)
- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [BLE GATT Services](https://www.bluetooth.com/specifications/gatt/services/)
