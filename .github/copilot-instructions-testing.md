# Testing Guidelines for YourTurn

## Testing Philosophy

- **Test behavior, not implementation**
- **Write tests that give confidence**
- **Tests should be fast, reliable, and maintainable**
- **Mock external dependencies (platform, network)**

## Test Structure

### Test Organization

```
test/
├── models_test.dart              # Model unit tests
├── controllers/
│   └── session_controller_test.dart
├── services/
│   ├── p2p_service_test.dart
│   └── mocks/
│       └── mock_p2p_service.dart
└── widgets/
    └── player_tile_test.dart
```

## Types of Tests

### 1. Unit Tests

Test individual classes and functions in isolation.

**Location**: `test/`

**Example Structure**:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yourturn/models.dart';

void main() {
  group('Player', () {
    test('creates player with valid data', () {
      final player = Player(
        id: '123',
        name: 'Alice',
        deviceId: 'device-1',
      );
      
      expect(player.id, '123');
      expect(player.name, 'Alice');
      expect(player.deviceId, 'device-1');
    });
    
    test('validates player name', () {
      expect(
        () => Player(id: '123', name: '', deviceId: 'device-1'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
```

### 2. Widget Tests

Test individual widgets and their interactions.

**Location**: `test/widgets/`

**Example**:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourturn/widgets/player_tile.dart';
import 'package:yourturn/models.dart';

void main() {
  testWidgets('PlayerTile displays player name', (tester) async {
    final player = Player(
      id: '123',
      name: 'Alice',
      deviceId: 'device-1',
    );
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerTile(player: player),
        ),
      ),
    );
    
    expect(find.text('Alice'), findsOneWidget);
  });
  
  testWidgets('PlayerTile shows current turn indicator', (tester) async {
    final player = Player(
      id: '123',
      name: 'Alice',
      deviceId: 'device-1',
    );
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayerTile(
            player: player,
            isCurrentTurn: true,
          ),
        ),
      ),
    );
    
    // Verify indicator is visible
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });
}
```

### 3. Integration Tests

Test complete features and user flows.

**Location**: `integration_test/`

**Example**:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yourturn/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Complete session flow', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    
    // Create session
    await tester.tap(find.text('Create Session'));
    await tester.pumpAndSettle();
    
    // Enter player name
    await tester.enterText(find.byType(TextField), 'Alice');
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    
    // Verify session is active
    expect(find.text('Alice'), findsOneWidget);
  });
}
```

## Testing Best Practices

### Unit Test Guidelines

#### Test One Thing

```dart
// ✅ Good: Tests one behavior
test('increments turn index', () {
  final controller = SessionController();
  controller.nextTurn();
  expect(controller.currentTurnIndex, 1);
});

// ❌ Bad: Tests multiple behaviors
test('handles turn logic', () {
  final controller = SessionController();
  controller.nextTurn();
  controller.addPlayer('Bob');
  controller.nextTurn();
  // Too much in one test
});
```

#### Use Descriptive Names

```dart
// ✅ Good: Clear what is being tested
test('wraps to first player after last player turn', () { });

// ❌ Bad: Unclear what is being tested
test('turn wrapping', () { });
```

#### Arrange-Act-Assert Pattern

```dart
test('adds player to session', () {
  // Arrange
  final controller = SessionController();
  final playerName = 'Alice';
  
  // Act
  controller.addPlayer(playerName);
  
  // Assert
  expect(controller.players.length, 1);
  expect(controller.players.first.name, playerName);
});
```

### Widget Test Guidelines

#### Pump and Settle

```dart
// Wait for all animations and async operations
await tester.pumpAndSettle();

// Or specify duration if needed
await tester.pump(Duration(seconds: 1));
```

#### Find Widgets

```dart
// By text
find.text('Button Label')

// By type
find.byType(ElevatedButton)

// By key
find.byKey(Key('my-widget'))

// By icon
find.byIcon(Icons.home)
```

#### Test User Interactions

```dart
// Tap
await tester.tap(find.text('Button'));
await tester.pumpAndSettle();

// Enter text
await tester.enterText(find.byType(TextField), 'Hello');

// Scroll
await tester.drag(find.byType(ListView), Offset(0, -200));
await tester.pumpAndSettle();
```

### Mocking Dependencies

#### Using Mockito

Add to `dev_dependencies` in pubspec.yaml:

```yaml
dev_dependencies:
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

Create mocks:

```dart
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:yourturn/services/p2p_service.dart';

@GenerateMocks([P2PService])
import 'mock_p2p_service.mocks.dart';

void main() {
  late MockP2PService mockService;
  
  setUp(() {
    mockService = MockP2PService();
  });
  
  test('initializes P2P service', () async {
    // Arrange
    when(mockService.initialize()).thenAnswer((_) async => true);
    
    // Act
    final result = await mockService.initialize();
    
    // Assert
    expect(result, true);
    verify(mockService.initialize()).called(1);
  });
}
```

Generate mocks:

```bash
flutter pub run build_runner build
```

## Test Coverage

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/models_test.dart

# Run with coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Coverage Goals

- **Unit tests**: Aim for 80%+ coverage
- **Critical paths**: 100% coverage
- **UI widgets**: Focus on behavior, not coverage %
- **Platform-specific code**: Mock and test interfaces

### Coverage Report

View in CI/CD or locally:

```bash
flutter test --coverage
lcov --list coverage/lcov.info
```

## Testing Platform-Specific Code

### Strategy

1. Define abstract interface (e.g., `P2PService`)
2. Create stub implementation for testing
3. Mock the interface in tests
4. Test platform implementations separately with integration tests

### Example

```dart
// Interface
abstract class P2PService {
  Future<bool> initialize();
  Future<List<Device>> discoverDevices();
}

// Stub for testing
class P2PServiceStub implements P2PService {
  @override
  Future<bool> initialize() async => true;
  
  @override
  Future<List<Device>> discoverDevices() async => [];
}

// Use in tests
test('uses P2P service', () async {
  final service = P2PServiceStub();
  final result = await service.initialize();
  expect(result, true);
});
```

## Test Data

### Test Fixtures

Create reusable test data:

```dart
// test/fixtures/players.dart
import 'package:yourturn/models.dart';

class TestPlayers {
  static Player alice() => Player(
    id: 'alice-id',
    name: 'Alice',
    deviceId: 'device-1',
  );
  
  static Player bob() => Player(
    id: 'bob-id',
    name: 'Bob',
    deviceId: 'device-2',
  );
  
  static List<Player> defaultPlayers() => [alice(), bob()];
}
```

Use in tests:

```dart
import 'fixtures/players.dart';

test('adds player to list', () {
  final controller = SessionController();
  final player = TestPlayers.alice();
  
  controller.addPlayer(player.name);
  expect(controller.players.first.name, player.name);
});
```

## Continuous Integration

### Running Tests in CI/CD

Tests run automatically in Codemagic during builds:

```yaml
# In codemagic.yaml
- name: Run unit tests
  script: |
    echo "Running Flutter unit tests..."
    flutter test --reporter compact
    echo "✅ All tests passed!"
  ignore_failure: true
```

### Test Reporting

- Tests must pass for production builds
- Dev builds can continue on test failure (ignore_failure: true)
- Review test failures in build logs

## Debugging Tests

### Print Debugging

```dart
test('debugs controller state', () {
  final controller = SessionController();
  print('Initial state: ${controller.players.length}');
  
  controller.addPlayer('Alice');
  print('After adding player: ${controller.players.length}');
  
  expect(controller.players.length, 1);
});
```

### Visual Debugging (Widget Tests)

```dart
testWidgets('debugs widget tree', (tester) async {
  await tester.pumpWidget(MyWidget());
  
  // Print widget tree
  debugDumpApp();
  
  // Print semantics tree
  debugDumpSemanticsTree();
});
```

## Test Maintenance

### When to Update Tests

- ✅ When behavior changes
- ✅ When bugs are fixed (add regression test)
- ✅ When new features are added
- ❌ When implementation changes (but behavior stays same)

### Refactoring Tests

- Extract common setup to `setUp()`
- Extract common assertions to helper functions
- Use test fixtures for reusable data
- Group related tests with `group()`

### Deleting Tests

Delete tests when:

- Feature is removed
- Test is redundant (covered by other tests)
- Test is flaky and can't be fixed

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)
- [Mockito Package](https://pub.dev/packages/mockito)
- [Widget Testing Guide](https://docs.flutter.dev/cookbook/testing/widget/introduction)
