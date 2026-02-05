import 'package:flutter_test/flutter_test.dart';
import 'package:yourturn/controllers/timer_controller.dart';

void main() {
  late TimerController controller;

  setUp(() {
    controller = TimerController();
  });

  tearDown(() {
    controller.dispose();
  });

  group('TimerController initial state', () {
    test('has zero remaining time initially', () {
      expect(controller.remaining, Duration.zero);
    });

    test('is not running initially', () {
      expect(controller.isRunning, isFalse);
    });

    test('is not flashing initially', () {
      expect(controller.isFlashing, isFalse);
    });

    test('is not expired initially', () {
      expect(controller.isExpired, isFalse);
    });

    test('has progress of 1.0 initially', () {
      expect(controller.progress, 1.0);
    });

    test('displays 00:00 initially', () {
      expect(controller.displayTime, '00:00');
    });
  });

  group('TimerController.startTimer', () {
    test('starts timer with correct duration', () {
      controller.startTimer(5);

      expect(controller.remaining, const Duration(minutes: 5));
      expect(controller.isRunning, isTrue);
    });

    test('does not start timer with null minutes', () {
      controller.startTimer(null);

      expect(controller.isRunning, isFalse);
      expect(controller.remaining, Duration.zero);
    });

    test('does not start timer with zero minutes', () {
      controller.startTimer(0);

      expect(controller.isRunning, isFalse);
    });

    test('does not start timer with negative minutes', () {
      controller.startTimer(-1);

      expect(controller.isRunning, isFalse);
    });

    test('resets flashing state on start', () {
      controller.startTimer(5);

      expect(controller.isFlashing, isFalse);
    });

    test('resets expired state on start', () {
      controller.startTimer(5);

      expect(controller.isExpired, isFalse);
    });

    test('displays correct time after start', () {
      controller.startTimer(5);

      expect(controller.displayTime, '05:00');
    });

    test('has progress of 1.0 at start', () {
      controller.startTimer(5);

      expect(controller.progress, 1.0);
    });
  });

  group('TimerController timer countdown', () {
    testWidgets('decrements remaining time each second', (tester) async {
      controller.startTimer(1);

      await tester.pump(const Duration(seconds: 1));

      expect(controller.remaining, const Duration(seconds: 59));
      controller.stopTimer();
    });

    testWidgets('updates display time as timer counts down', (tester) async {
      controller.startTimer(1);

      await tester.pump(const Duration(seconds: 1));

      expect(controller.displayTime, '00:59');
      controller.stopTimer();
    });

    testWidgets('updates progress as timer counts down', (tester) async {
      controller.startTimer(1);
      final initialProgress = controller.progress;

      await tester.pump(const Duration(seconds: 30));

      expect(controller.progress, lessThan(initialProgress));
      expect(controller.progress, closeTo(0.5, 0.02));
      controller.stopTimer();
    });
  });

  group('TimerController.stopTimer', () {
    test('stops running timer', () {
      controller.startTimer(5);
      expect(controller.isRunning, isTrue);

      controller.stopTimer();

      expect(controller.isRunning, isFalse);
    });

    test('resets flashing state', () {
      controller.startTimer(5);
      controller.stopTimer();

      expect(controller.isFlashing, isFalse);
    });

    test('resets expired state', () {
      controller.startTimer(5);
      controller.stopTimer();

      expect(controller.isExpired, isFalse);
    });
  });

  group('TimerController.resetTimer', () {
    test('stops and restarts with new duration', () {
      controller.startTimer(5);
      controller.resetTimer(3);

      expect(controller.remaining, const Duration(minutes: 3));
      expect(controller.isRunning, isTrue);
    });

    test('resets remaining to zero before starting', () {
      controller.startTimer(5);
      controller.resetTimer(null);

      expect(controller.remaining, Duration.zero);
      expect(controller.isRunning, isFalse);
    });

    test('does not start timer when minutes is null', () {
      controller.resetTimer(null);

      expect(controller.isRunning, isFalse);
    });

    test('does not start timer when minutes is zero', () {
      controller.resetTimer(0);

      expect(controller.isRunning, isFalse);
    });
  });

  group('TimerController.pauseTimer', () {
    test('stops timer without resetting remaining time', () {
      controller.startTimer(5);
      controller.pauseTimer();

      expect(controller.isRunning, isFalse);
      expect(controller.remaining, const Duration(minutes: 5));
    });

    testWidgets('preserves remaining time after pause', (tester) async {
      controller.startTimer(1);
      await tester.pump(const Duration(seconds: 10));

      controller.pauseTimer();

      expect(controller.remaining, const Duration(seconds: 50));
      expect(controller.isRunning, isFalse);
    });
  });

  group('TimerController.resumeTimer', () {
    testWidgets('resumes paused timer', (tester) async {
      controller.startTimer(1);
      await tester.pump(const Duration(seconds: 10));
      controller.pauseTimer();

      controller.resumeTimer();

      expect(controller.isRunning, isTrue);
      expect(controller.remaining, const Duration(seconds: 50));
      controller.stopTimer();
    });

    test('does not resume if remaining time is zero', () {
      controller.startTimer(1);
      controller.stopTimer();

      final resumed = controller.resumeTimer();

      expect(resumed, isFalse);
      expect(controller.isRunning, isFalse);
    });

    test('does not resume if already running', () {
      controller.startTimer(5);
      final beforeRemaining = controller.remaining;

      controller.resumeTimer();

      expect(controller.remaining, beforeRemaining);
    });
  });

  group('TimerController warning state', () {
    testWidgets('sets isFlashing at warning threshold', (tester) async {
      controller.startTimer(1);
      expect(controller.isFlashing, isFalse);

      // Advance to 10 seconds remaining (warning threshold)
      await tester.pump(const Duration(seconds: 50));

      expect(controller.isFlashing, isTrue);
      controller.stopTimer();
    });

    testWidgets('calls onWarningStart callback at threshold', (tester) async {
      var warningCalled = false;
      controller.onWarningStart = () => warningCalled = true;
      controller.startTimer(1);

      await tester.pump(const Duration(seconds: 50));

      expect(warningCalled, isTrue);
      controller.stopTimer();
    });

    testWidgets('only calls onWarningStart once', (tester) async {
      var callCount = 0;
      controller.onWarningStart = () => callCount++;
      controller.startTimer(1);

      await tester.pump(const Duration(seconds: 50));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(callCount, 1);
      controller.stopTimer();
    });
  });

  group('TimerController expiration', () {
    testWidgets('sets isExpired when timer reaches zero', (tester) async {
      controller.startTimer(1);

      await tester.pump(const Duration(seconds: 60));

      expect(controller.isExpired, isTrue);
    });

    testWidgets('stops running when timer expires', (tester) async {
      controller.startTimer(1);

      await tester.pump(const Duration(seconds: 60));

      expect(controller.isRunning, isFalse);
    });

    testWidgets('sets remaining to zero when expired', (tester) async {
      controller.startTimer(1);

      await tester.pump(const Duration(seconds: 60));

      expect(controller.remaining, Duration.zero);
    });

    testWidgets('calls onTimerExpired callback', (tester) async {
      var expiredCalled = false;
      controller.onTimerExpired = () => expiredCalled = true;
      controller.startTimer(1);

      await tester.pump(const Duration(seconds: 60));

      expect(expiredCalled, isTrue);
    });

    testWidgets('has progress of 0.0 when expired', (tester) async {
      controller.startTimer(1);

      await tester.pump(const Duration(seconds: 60));

      expect(controller.progress, 0.0);
    });
  });

  group('TimerController.progress', () {
    test('returns 1.0 when initial duration is zero', () {
      expect(controller.progress, 1.0);
    });

    test('returns 1.0 at start of timer', () {
      controller.startTimer(5);

      expect(controller.progress, 1.0);
    });

    testWidgets('returns correct ratio during countdown', (tester) async {
      controller.startTimer(2);

      await tester.pump(const Duration(minutes: 1));

      expect(controller.progress, closeTo(0.5, 0.01));
      controller.stopTimer();
    });
  });

  group('TimerController.displayTime', () {
    test('formats time correctly', () {
      controller.startTimer(5);

      expect(controller.displayTime, '05:00');
    });

    testWidgets('updates format during countdown', (tester) async {
      controller.startTimer(1);
      await tester.pump(const Duration(seconds: 30));

      expect(controller.displayTime, '00:30');
      controller.stopTimer();
    });
  });

  group('TimerController.warningThresholdSeconds', () {
    test('is 10 seconds', () {
      expect(TimerController.warningThresholdSeconds, 10);
    });
  });

  group('TimerController notifies listeners', () {
    test('notifies on startTimer', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.startTimer(5);

      expect(notified, isTrue);
    });

    test('notifies on stopTimer', () {
      controller.startTimer(5);
      var notified = false;
      controller.addListener(() => notified = true);

      controller.stopTimer();

      expect(notified, isTrue);
    });

    test('notifies on pauseTimer', () {
      controller.startTimer(5);
      var notified = false;
      controller.addListener(() => notified = true);

      controller.pauseTimer();

      expect(notified, isTrue);
    });

    test('notifies on resumeTimer', () {
      controller.startTimer(5);
      controller.pauseTimer();
      var notified = false;
      controller.addListener(() => notified = true);

      controller.resumeTimer();

      expect(notified, isTrue);
    });

    testWidgets('notifies on each tick', (tester) async {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.startTimer(1);
      notifyCount = 0; // Reset after startTimer notification

      await tester.pump(const Duration(seconds: 3));

      expect(notifyCount, 3);
      controller.stopTimer();
    });
  });
}
