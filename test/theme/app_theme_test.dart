import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourturn/theme/app_theme.dart';

void main() {
  group('AppTheme.formatDuration', () {
    test('returns "0 seconds" for zero duration', () {
      final result = AppTheme.formatDuration(Duration.zero);

      expect(result, '0 seconds');
    });

    test('returns singular "second" for 1 second', () {
      final result = AppTheme.formatDuration(const Duration(seconds: 1));

      expect(result, '1 second');
    });

    test('returns plural "seconds" for multiple seconds', () {
      final result = AppTheme.formatDuration(const Duration(seconds: 45));

      expect(result, '45 seconds');
    });

    test('returns singular "minute" for 1 minute', () {
      final result = AppTheme.formatDuration(const Duration(minutes: 1));

      expect(result, '1 minute');
    });

    test('returns plural "minutes" for multiple minutes', () {
      final result = AppTheme.formatDuration(const Duration(minutes: 5));

      expect(result, '5 minutes');
    });

    test('returns combined format for minutes and seconds', () {
      final result = AppTheme.formatDuration(
        const Duration(minutes: 3, seconds: 45),
      );

      expect(result, '3 minutes 45 seconds');
    });

    test('handles singular minute with plural seconds', () {
      final result = AppTheme.formatDuration(
        const Duration(minutes: 1, seconds: 30),
      );

      expect(result, '1 minute 30 seconds');
    });

    test('handles plural minutes with singular second', () {
      final result = AppTheme.formatDuration(
        const Duration(minutes: 5, seconds: 1),
      );

      expect(result, '5 minutes 1 second');
    });

    test('handles singular minute with singular second', () {
      final result = AppTheme.formatDuration(
        const Duration(minutes: 1, seconds: 1),
      );

      expect(result, '1 minute 1 second');
    });

    test('handles large durations by converting to minutes', () {
      final result = AppTheme.formatDuration(
        const Duration(hours: 1, minutes: 30, seconds: 45),
      );

      expect(result, '90 minutes 45 seconds');
    });
  });

  group('AppTheme.formatTimerDisplay', () {
    test('formats zero duration as 00:00', () {
      final result = AppTheme.formatTimerDisplay(Duration.zero);

      expect(result, '00:00');
    });

    test('pads single digit minutes', () {
      final result = AppTheme.formatTimerDisplay(const Duration(minutes: 5));

      expect(result, '05:00');
    });

    test('pads single digit seconds', () {
      final result = AppTheme.formatTimerDisplay(const Duration(seconds: 5));

      expect(result, '00:05');
    });

    test('formats double digit minutes correctly', () {
      final result = AppTheme.formatTimerDisplay(const Duration(minutes: 12));

      expect(result, '12:00');
    });

    test('formats double digit seconds correctly', () {
      final result = AppTheme.formatTimerDisplay(const Duration(seconds: 45));

      expect(result, '00:45');
    });

    test('formats combined minutes and seconds', () {
      final result = AppTheme.formatTimerDisplay(
        const Duration(minutes: 5, seconds: 30),
      );

      expect(result, '05:30');
    });

    test('formats edge case of 59 seconds', () {
      final result = AppTheme.formatTimerDisplay(const Duration(seconds: 59));

      expect(result, '00:59');
    });

    test('wraps seconds at 60', () {
      final result = AppTheme.formatTimerDisplay(const Duration(seconds: 65));

      expect(result, '01:05');
    });

    test('handles maximum timer setting (15 minutes)', () {
      final result = AppTheme.formatTimerDisplay(const Duration(minutes: 15));

      expect(result, '15:00');
    });
  });

  group('AppTheme.getConnectionStatusColor', () {
    test('returns connectionActive for connected status', () {
      final result = AppTheme.getConnectionStatusColor(
        ConnectionStatusType.connected,
      );

      expect(result, AppTheme.connectionActive);
    });

    test('returns connectionInactive for disconnected status', () {
      final result = AppTheme.getConnectionStatusColor(
        ConnectionStatusType.disconnected,
      );

      expect(result, AppTheme.connectionInactive);
    });

    test('returns connectionPending for connecting status', () {
      final result = AppTheme.getConnectionStatusColor(
        ConnectionStatusType.connecting,
      );

      expect(result, AppTheme.connectionPending);
    });
  });

  group('AppTheme colors', () {
    test('activePlayerBackground is green', () {
      expect(AppTheme.activePlayerBackground, const Color(0xFF129C26));
    });

    test('waitingPlayerBackground is red', () {
      expect(AppTheme.waitingPlayerBackground, const Color(0xFFC03317));
    });

    test('connectionActive is green', () {
      expect(AppTheme.connectionActive, const Color(0xFF4CAF50));
    });

    test('connectionInactive is grey', () {
      expect(AppTheme.connectionInactive, const Color(0xFF9E9E9E));
    });

    test('connectionPending is amber', () {
      expect(AppTheme.connectionPending, const Color(0xFFFFC107));
    });
  });

  group('AppTheme constants', () {
    test('connectionDotSize is 10', () {
      expect(AppTheme.connectionDotSize, 10);
    });

    test('currentPlayerDotSize is 12', () {
      expect(AppTheme.currentPlayerDotSize, 12);
    });

    test('playerTileHeight is 64', () {
      expect(AppTheme.playerTileHeight, 64);
    });

    test('doneButtonAreaRatio is 0.33', () {
      expect(AppTheme.doneButtonAreaRatio, 0.33);
    });
  });

  group('AppTheme.buildTheme', () {
    test('returns a valid ThemeData', () {
      final theme = AppTheme.buildTheme();

      expect(theme, isA<ThemeData>());
    });

    test('uses Material 3', () {
      final theme = AppTheme.buildTheme();

      expect(theme.useMaterial3, isTrue);
    });

    test('has centered app bar title', () {
      final theme = AppTheme.buildTheme();

      expect(theme.appBarTheme.centerTitle, isTrue);
    });

    test('has zero app bar elevation', () {
      final theme = AppTheme.buildTheme();

      expect(theme.appBarTheme.elevation, 0);
    });
  });
}
