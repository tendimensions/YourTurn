# YourTurn

A local peer-to-peer turn notification system for tabletop games, built with Flutter for cross-platform support (Android & iOS).

**YourTurn** eliminates the need for players to constantly check whose turn it is during board games. Players connect their devices via local networking, and the app automatically notifies the next player when it's their turn with visual indicators and optional timers.

## Features

- **Local P2P Connectivity**: No internet required - uses Bluetooth and local networking
- **Cross-Platform**: Works seamlessly between iOS and Android devices
- **Turn Tracking**: Visual indicators (green/red screens) show whose turn it is
- **Player Management**: Support for 2-8 players with customizable turn order
- **Optional Timer**: Countdown timer with haptic feedback when time expires
- **Time Tracking**: See total time each player spent on their turns
- **Team Leader Controls**: Menu for managing game settings mid-game

> **Network Requirement**: All devices must be connected to the same WiFi network. This is the current implementation for cross-platform support - while not the ideal long-term solution, it provides the simplest and most reliable connectivity for mixed iOS/Android groups. Internet access is not required, only a shared local network.

## Getting Started

### Prerequisites

- Flutter SDK 3.27.0 or higher
- iOS 12.0+ / Android 6.0+ (API level 23)
- Physical devices for testing (P2P requires real hardware)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/tendimensions/YourTurn.git
   cd YourTurn
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run on physical device:
   ```bash
   flutter run
   ```

**Note**: The app currently uses a stub P2P implementation for development. Real P2P connectivity implementation is in progress (see [Connectivity Design](docs/connectivity-design.md)).

## Architecture

YourTurn follows a **Provider-based state management** pattern with clear separation of concerns:

```
lib/
├── main.dart                    # App entry point
├── models.dart                  # Data models (Player, Session)
├── controllers/                 # Business logic layer
│   └── session_controller.dart  # Game session state management
├── services/                    # Platform-specific services
│   ├── p2p_service.dart        # P2P interface definition
│   └── p2p_service_stub.dart   # Development stub
└── widgets/                     # UI components
    └── player_tile.dart        # Reusable player UI
```

For detailed architecture guidelines, see [Architecture Documentation](.github/copilot-instructions-architecture.md).

## Connectivity Implementation

The P2P connectivity system uses an **abstract service interface** with swappable implementations:

**Phase 1 (Current)**: BLE-only implementation for cross-platform support  
**Phase 2 (Planned)**: Platform-specific enhancements (MultipeerConnectivity for iOS, Nearby Connections for Android)

For complete connectivity design and technical decisions, see [Connectivity Design Document](docs/connectivity-design.md).

## Development

### Building

```bash
# Debug build
flutter run

# Release build (Android)
flutter build apk --release

# Release build (iOS)
flutter build ios --release
```

### Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

For testing guidelines, see [Testing Documentation](.github/copilot-instructions-testing.md).

### Required Permissions

#### iOS (Info.plist)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>YourTurn needs Bluetooth to connect with nearby players</string>

<key>NSLocalNetworkUsageDescription</key>
<string>YourTurn uses local network to discover nearby game sessions</string>
```

#### Android (AndroidManifest.xml)
```xml
<!-- Bluetooth permissions -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />

<!-- Location permissions (required for BLE scanning) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

## Deployment

Builds are automatically deployed to Firebase App Distribution via Codemagic CI/CD. See `codemagic.yaml` for configuration.

For manual deployment setup:
- [Firebase Setup Guide](docs/firebase-setup.md)
- [iOS Code Signing Setup](docs/ios-signing-setup-guide.md)

## Documentation

### Project Documentation
- [Requirements](docs/requirements.md) - Complete functional and technical requirements
- [Connectivity Design](docs/connectivity-design.md) - P2P implementation strategy and decisions
- [Initial Conversation](docs/initial-conversation.txt) - Project genesis notes

### Development Guidelines
- [Architecture Guidelines](.github/copilot-instructions-architecture.md) - Code organization and patterns
- [Connectivity Guidelines](.github/copilot-instructions-connectivity.md) - P2P networking details
- [Documentation Guidelines](.github/copilot-instructions-documentation.md) - Documentation standards
- [Testing Guidelines](.github/copilot-instructions-testing.md) - Testing strategies
- [UI Guidelines](.github/copilot-instructions-ui.md) - Design system and components

## Contributing

1. Read the [Architecture Guidelines](.github/copilot-instructions-architecture.md)
2. Follow the [Documentation Standards](.github/copilot-instructions-documentation.md)
3. Write tests following [Testing Guidelines](.github/copilot-instructions-testing.md)
4. Use the [UI Design System](.github/copilot-instructions-ui.md) for consistency

## License

MIT License - See LICENSE file for details

## Roadmap

### Phase 1 (Current - MVP)
- [x] Basic UI structure and navigation
- [x] Session management (create/join)
- [x] Player management and turn order
- [ ] BLE P2P implementation
- [ ] Timer feature with haptic feedback
- [ ] Time tracking and end-game summary

### Phase 2 (Planned)
- [ ] Platform-specific P2P enhancements (MultipeerConnectivity/Nearby)
- [ ] Connection resilience improvements
- [ ] Reorder turn order mid-game
- [ ] Change start player mid-game
- [ ] Dynamic timer adjustment

### Phase 3 (Future)
- [ ] Turn Focus feature (app locking)
- [ ] Pause/resume game
- [ ] Player reconnection logic
- [ ] Remove player mid-game
- [ ] Game statistics and history

---

Built with ❤️ for tabletop gaming enthusiasts
