import 'dart:async';
import 'package:flutter/foundation.dart';
import '../theme/app_theme.dart';

/// Controller for managing the turn timer countdown.
/// Handles warning states (flashing at 10 seconds) and expiration.
class TimerController extends ChangeNotifier {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  Duration _initialDuration = Duration.zero;
  bool _isRunning = false;
  bool _isFlashing = false;
  bool _isExpired = false;

  /// Callback when timer expires (reaches 00:00)
  VoidCallback? onTimerExpired;

  /// Callback when warning starts (10 seconds remaining)
  VoidCallback? onWarningStart;

  /// Warning threshold in seconds
  static const int warningThresholdSeconds = 10;

  // === Public Getters ===

  /// Time remaining on the timer
  Duration get remaining => _remaining;

  /// Whether the timer is currently running
  bool get isRunning => _isRunning;

  /// Whether the timer is in warning state (< 10 seconds)
  bool get isFlashing => _isFlashing;

  /// Whether the timer has expired (reached 00:00)
  bool get isExpired => _isExpired;

  /// Display time in MM:SS format
  String get displayTime => AppTheme.formatTimerDisplay(_remaining);

  /// Progress from 0.0 (expired) to 1.0 (full time)
  double get progress {
    if (_initialDuration.inSeconds == 0) return 1.0;
    return _remaining.inSeconds / _initialDuration.inSeconds;
  }

  // === Public Methods ===

  /// Start the timer with the specified number of minutes.
  /// If minutes is null or 0, the timer will not run.
  void startTimer(int? minutes) {
    stopTimer();

    if (minutes == null || minutes <= 0) {
      return;
    }

    _initialDuration = Duration(minutes: minutes);
    _remaining = _initialDuration;
    _isRunning = true;
    _isFlashing = false;
    _isExpired = false;

    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    notifyListeners();
  }

  /// Stop the timer and reset state.
  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _isFlashing = false;
    _isExpired = false;
    _remaining = Duration.zero;
    notifyListeners();
  }

  /// Reset the timer with new duration (for next player's turn).
  void resetTimer(int? minutes) {
    stopTimer();
    _remaining = Duration.zero;
    notifyListeners();

    if (minutes != null && minutes > 0) {
      startTimer(minutes);
    }
  }

  /// Pause the timer (keeps current state)
  void pauseTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    notifyListeners();
  }

  /// Resume the timer from paused state
  bool resumeTimer() {
    if (_remaining.inSeconds > 0 && !_isRunning) {
      _isRunning = true;
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
      notifyListeners();
      return true;
    }
    return false;
  }

  // === Private Methods ===

  void _tick(Timer timer) {
    if (_remaining.inSeconds <= 0) {
      _handleExpiration();
      return;
    }

    _remaining = _remaining - const Duration(seconds: 1);

    // Check for warning threshold
    if (!_isFlashing && _remaining.inSeconds <= warningThresholdSeconds) {
      _isFlashing = true;
      onWarningStart?.call();
    }

    // Check for expiration
    if (_remaining.inSeconds <= 0) {
      _handleExpiration();
    }

    notifyListeners();
  }

  void _handleExpiration() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _isExpired = true;
    _remaining = Duration.zero;
    onTimerExpired?.call();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
