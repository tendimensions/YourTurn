# Architecture Guidelines for YourTurn

## Project Overview

YourTurn is a local peer-to-peer turn notification system for tabletop games, built with Flutter for cross-platform support (Android & iOS).

## Architectural Pattern

This project follows a **Provider-based State Management** pattern with clear separation of concerns.

### Core Structure

```
lib/
├── main.dart                    # App entry point
├── models.dart                  # Data models
├── controllers/                 # Business logic layer
│   └── session_controller.dart  # Game session state management
├── services/                    # Platform-specific services
│   ├── p2p_service.dart        # P2P interface definition
│   └── p2p_service_stub.dart   # Platform-agnostic stub
└── widgets/                     # UI components
    └── player_tile.dart        # Reusable player UI components
```

## Design Principles

### 1. Separation of Concerns

- **Models**: Pure data classes with no business logic
- **Controllers**: Manage state and coordinate between services and UI
- **Services**: Handle platform-specific functionality (Bluetooth, network, etc.)
- **Widgets**: Presentation layer only, consume state from controllers

### 2. State Management

- Use **Provider** package for dependency injection and state management
- Controllers extend `ChangeNotifier` for reactive state updates
- Keep state as high as necessary, as low as possible in the widget tree

### 3. Platform Abstraction

- Service interfaces define contracts (e.g., `p2p_service.dart`)
- Platform-specific implementations use conditional imports
- Stub implementations for development/testing without platform dependencies

### 4. Session-Based Architecture

- Each game session is an isolated state container
- Sessions manage:
  - Player list and turn order
  - Current turn state
  - P2P connections
  - Local notifications

## Key Components

### SessionController

**Responsibility**: Manages game session state, player turns, and P2P coordination

**Key Methods**:

- Session lifecycle (create, join, leave, end)
- Turn management (next turn, specific player turn)
- Player management (add, remove, reorder)

### P2PService

**Responsibility**: Abstract interface for peer-to-peer communication

**Implementations**:

- Bluetooth Low Energy (BLE) for close-range
- Local network discovery for WiFi Direct
- Stub for testing without platform dependencies

### Models

**Player**: Represents a game participant

- ID (UUID)
- Name
- Device identifier
- Turn order position

**Session**: Represents an active game

- Session ID
- Player list
- Current turn index
- Connection state

## Code Organization Guidelines

### File Naming

- `snake_case` for all Dart files
- Controllers: `*_controller.dart`
- Services: `*_service.dart`
- Models: Use `models.dart` for simple models, separate files for complex ones
- Widgets: `*_widget.dart` or descriptive name (e.g., `player_tile.dart`)

### Class Structure

```dart
class ExampleController extends ChangeNotifier {
  // 1. Private fields
  String _privateField;
  
  // 2. Public getters
  String get publicField => _privateField;
  
  // 3. Constructor
  ExampleController();
  
  // 4. Public methods
  void publicMethod() { }
  
  // 5. Private methods
  void _privateMethod() { }
  
  // 6. Dispose (if needed)
  @override
  void dispose() {
    super.dispose();
  }
}
```

## Dependency Management

### Current Dependencies

- `provider`: State management
- `uuid`: Unique identifier generation
- `cupertino_icons`: iOS-style icons

### Adding New Dependencies

1. Add to `pubspec.yaml`
2. Run `flutter pub get`
3. Update documentation if it affects architecture
4. Consider platform compatibility (Android/iOS)

## Future Architecture Considerations

### Planned Enhancements

- **Persistence Layer**: Local storage for session history
- **Cloud Sync** (optional): Backup/restore sessions across devices
- **Audio Notifications**: Sound alerts for turn changes
- **Haptic Feedback**: Vibration patterns for notifications

### Scalability

- Keep P2P mesh size reasonable (recommended: 2-8 players)
- Design for local-first, occasional connectivity
- Handle network splits gracefully

## Anti-Patterns to Avoid

❌ **Don't**: Put business logic in widgets
✅ **Do**: Keep widgets pure presentation, logic in controllers

❌ **Don't**: Make services stateful (except connection state)
✅ **Do**: Use controllers for application state

❌ **Don't**: Directly couple widgets to platform-specific code
✅ **Do**: Use service abstractions with platform implementations

❌ **Don't**: Share state through global variables
✅ **Do**: Use Provider for dependency injection

## Testing Strategy

- Unit tests for models and controllers
- Widget tests for UI components
- Integration tests for P2P service implementations
- Mock services for testing without platform dependencies

## References

- [Flutter Architecture Samples](https://github.com/brianegan/flutter_architecture_samples)
- [Provider Package](https://pub.dev/packages/provider)
- [Flutter Best Practices](https://docs.flutter.dev/development/data-and-backend/state-mgmt/options)
