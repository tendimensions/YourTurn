import 'package:flutter/material.dart';

/// Centralized theming for YourTurn app.
/// All UI colors, fonts, and sizes are defined here for consistency.
class AppTheme {
  AppTheme._();

  // === COLORS (from requirements) ===
  static const Color activePlayerBackground = Color(0xFF129C26);
  static const Color waitingPlayerBackground = Color(0xFFC03317);
  static const Color connectionActive = Color(0xFF4CAF50);
  static const Color connectionInactive = Color(0xFF9E9E9E);
  static const Color connectionPending = Color(0xFFFFC107);
  static const Color currentPlayerIndicator = Color(0xFF4CAF50);

  // === TYPOGRAPHY ===

  /// Timer display at top center (MM:SS format)
  static const TextStyle timerDisplay = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    fontFamily: 'monospace',
    letterSpacing: 4,
  );

  /// Player name in list
  static const TextStyle playerName = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  /// Player name on colored backgrounds
  static const TextStyle playerNameLight = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  /// Time summary - player name
  static const TextStyle timeSummaryName = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  /// Time summary - time value
  static const TextStyle timeSummaryTime = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.black54,
  );

  /// "DONE" button text
  static const TextStyle doneButtonText = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  /// Session code display
  static const TextStyle sessionCode = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 2,
  );

  /// Section headers
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  // === SIZES ===
  static const double connectionDotSize = 10;
  static const double currentPlayerDotSize = 12;
  static const double playerTileHeight = 64;
  static const double doneButtonAreaRatio = 0.33; // Bottom third of screen

  // === BUTTON STYLES ===

  /// Style for the large "DONE" button
  static final ButtonStyle doneButton = ElevatedButton.styleFrom(
    backgroundColor: Colors.white.withValues(alpha: 0.3),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 64),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Colors.white, width: 3),
    ),
    elevation: 0,
  );

  // === THEME DATA ===

  /// Build the MaterialApp theme
  static ThemeData buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: activePlayerBackground,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  // === HELPER METHODS ===

  /// Format duration as human-readable string (e.g., "15 minutes 32 seconds")
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    if (minutes == 0 && seconds == 0) {
      return '0 seconds';
    } else if (minutes == 0) {
      return '$seconds second${seconds != 1 ? 's' : ''}';
    } else if (seconds == 0) {
      return '$minutes minute${minutes != 1 ? 's' : ''}';
    } else {
      return '$minutes minute${minutes != 1 ? 's' : ''} '
          '$seconds second${seconds != 1 ? 's' : ''}';
    }
  }

  /// Format duration as MM:SS for timer display
  static String formatTimerDisplay(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Get connection status color
  static Color getConnectionStatusColor(ConnectionStatusType status) {
    switch (status) {
      case ConnectionStatusType.connected:
        return connectionActive;
      case ConnectionStatusType.disconnected:
        return connectionInactive;
      case ConnectionStatusType.connecting:
        return connectionPending;
    }
  }
}

/// Connection status types for color mapping
enum ConnectionStatusType {
  connected,
  disconnected,
  connecting,
}
