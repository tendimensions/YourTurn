import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Displays the countdown timer in MM:SS format at the top of the screen.
/// Supports flashing animation when timer is in warning state.
class TimerDisplay extends StatefulWidget {
  final String displayTime;
  final bool isFlashing;

  const TimerDisplay({
    super.key,
    required this.displayTime,
    this.isFlashing = false,
  });

  @override
  State<TimerDisplay> createState() => _TimerDisplayState();
}

class _TimerDisplayState extends State<TimerDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(TimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlashing && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isFlashing && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: widget.isFlashing ? _opacityAnimation.value : 1.0,
          child: Text(
            widget.displayTime,
            style: AppTheme.timerDisplay,
          ),
        );
      },
    );
  }
}
