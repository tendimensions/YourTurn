# Connectivity Guidelines for YourTurn

## Overview

YourTurn requires local peer-to-peer (P2P) networking to enable turn notifications between devices playing the same tabletop game. This is a **critical and complex** component that enables the core functionality of the app.

## P2P Architecture

### Network Topology

```
Device A (Host)
    │
    ├── Device B (Player)
    ├── Device C (Player)
    └── Device D (Player)

Mesh Network:
- 1 Host device creates the session
- Multiple player devices join the session
- All devices can send/receive turn notifications
- Fallback to star topology if mesh is complex
```

### Connection Types

#### Primary: Bluetooth Low Energy (BLE)

**Pros:**

- No WiFi required
- Lower power consumption
- Works in most environments
- Good range (up to 100m clear line of sight)

**Cons:**

- Limited simultaneous connections (typically 7-8 devices)
- Can be affected by interference
- Platform-specific implementation differences

#### Secondary: Local WiFi (WiFi Direct/Hotspot)

**Pros:**

- Higher bandwidth
- More stable connections
- Better for larger groups (8+ players)

**Cons:**

- Requires WiFi to be enabled
- May interfere with internet connectivity
- Platform differences (Android WiFi Direct vs iOS Multipeer)

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

#### Android (BLE + WiFi Direct)

**Location**: `lib/services/p2p_service_android.dart`

**Key Technologies**:

- Bluetooth Low Energy (BLE) APIs
- WiFi Direct APIs
- Service Discovery (mDNS/Bonjour)

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
```

**Implementation Notes**:

- Use BLE GATT server/client pattern
- Implement service UUID for app identification
- Handle runtime permission requests
- Implement connection state callbacks
- Handle device bonding if required

#### iOS (BLE + Multipeer Connectivity)

**Location**: `lib/services/p2p_service_ios.swift`

**Key Technologies**:

- Core Bluetooth framework
- Multipeer Connectivity framework
- Bonjour/mDNS

**Permissions Required**:

```xml
<!-- Info.plist -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>YourTurn needs Bluetooth to connect with nearby players</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>YourTurn needs Bluetooth to connect with nearby players</string>
<key>NSLocalNetworkUsageDescription</key>
<string>YourTurn needs local network access to discover nearby game sessions</string>
```

**Implementation Notes**:

- Use CBCentralManager for BLE central role
- Use CBPeripheralManager for BLE peripheral role
- MCNearbyServiceAdvertiser for session hosting
- MCNearbyServiceBrowser for session discovery
- MCSession for data transmission

#### Stub Implementation

**Location**: `lib/services/p2p_service_stub.dart`

**Purpose**: Development and testing without platform dependencies

```dart
class P2PServiceStub implements P2PService {
  @override
  Future<bool> initialize() async {
    print('[Stub] P2P initialized');
    return true;
  }
  
  @override
  Stream<Device> startDiscovery() {
    // Return mock devices for testing
    return Stream.fromIterable([
      Device(id: 'stub-1', name: 'Test Device 1'),
      Device(id: 'stub-2', name: 'Test Device 2'),
    ]);
  }
  
  // ... other stub implementations
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

## Resources

- [Android BLE Guide](https://developer.android.com/guide/topics/connectivity/bluetooth-le)
- [iOS Core Bluetooth](https://developer.apple.com/documentation/corebluetooth)
- [iOS Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity)
- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [BLE GATT Services](https://www.bluetooth.com/specifications/gatt/services/)
