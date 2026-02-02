import 'dart:async';
import 'package:flutter/services.dart';

/// Service for haptic feedback (vibration)
/// Used for timer expiration notifications
abstract class HapticService {
  /// Single vibration
  Future<void> vibrate();

  /// Start pulsing vibration (continues until stopped)
  void startPulsingVibration();

  /// Stop pulsing vibration
  void stopPulsingVibration();

  /// Dispose and cleanup
  void dispose();
}

/// Default implementation using HapticFeedback
class HapticServiceImpl implements HapticService {
  Timer? _pulseTimer;
  bool _isPulsing = false;

  @override
  Future<void> vibrate() async {
    await HapticFeedback.heavyImpact();
  }

  @override
  void startPulsingVibration() {
    if (_isPulsing) return;
    _isPulsing = true;

    // Vibrate immediately
    vibrate();

    // Continue pulsing every 1 second
    _pulseTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPulsing) {
        vibrate();
      }
    });
  }

  @override
  void stopPulsingVibration() {
    _isPulsing = false;
    _pulseTimer?.cancel();
    _pulseTimer = null;
  }

  @override
  void dispose() {
    stopPulsingVibration();
  }
}

/// Stub implementation for testing
class HapticServiceStub implements HapticService {
  int vibrateCount = 0;
  bool isPulsing = false;

  @override
  Future<void> vibrate() async {
    vibrateCount++;
  }

  @override
  void startPulsingVibration() {
    isPulsing = true;
  }

  @override
  void stopPulsingVibration() {
    isPulsing = false;
  }

  @override
  void dispose() {
    isPulsing = false;
  }
}
