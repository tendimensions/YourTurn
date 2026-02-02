import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Service for screen-related functionality:
/// - Wake lock (keep screen on during active game)
/// - Orientation lock (portrait only)
abstract class ScreenService {
  /// Enable wake lock to keep screen on
  Future<void> enableWakeLock();

  /// Disable wake lock to allow screen to sleep
  Future<void> disableWakeLock();

  /// Lock orientation to portrait mode
  Future<void> lockPortraitOrientation();

  /// Unlock orientation (allow all orientations)
  Future<void> unlockOrientation();

  /// Dispose and cleanup
  Future<void> dispose();
}

/// Default implementation using wakelock_plus and SystemChrome
class ScreenServiceImpl implements ScreenService {
  bool _wakeLockEnabled = false;

  @override
  Future<void> enableWakeLock() async {
    if (!_wakeLockEnabled) {
      await WakelockPlus.enable();
      _wakeLockEnabled = true;
    }
  }

  @override
  Future<void> disableWakeLock() async {
    if (_wakeLockEnabled) {
      await WakelockPlus.disable();
      _wakeLockEnabled = false;
    }
  }

  @override
  Future<void> lockPortraitOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Future<void> unlockOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  Future<void> dispose() async {
    await disableWakeLock();
    await unlockOrientation();
  }
}

/// Stub implementation for testing
class ScreenServiceStub implements ScreenService {
  bool wakeLockEnabled = false;
  bool orientationLocked = false;

  @override
  Future<void> enableWakeLock() async {
    wakeLockEnabled = true;
  }

  @override
  Future<void> disableWakeLock() async {
    wakeLockEnabled = false;
  }

  @override
  Future<void> lockPortraitOrientation() async {
    orientationLocked = true;
  }

  @override
  Future<void> unlockOrientation() async {
    orientationLocked = false;
  }

  @override
  Future<void> dispose() async {
    wakeLockEnabled = false;
    orientationLocked = false;
  }
}
