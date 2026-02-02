import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Large "DONE" button displayed in the bottom third of the screen
/// for the active player.
class DoneButton extends StatelessWidget {
  final VoidCallback onPressed;

  const DoneButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ElevatedButton(
          onPressed: onPressed,
          style: AppTheme.doneButton,
          child: const Text(
            'DONE',
            style: AppTheme.doneButtonText,
          ),
        ),
      ),
    );
  }
}
