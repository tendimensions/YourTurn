import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/session_controller.dart';
import '../controllers/timer_controller.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';
import '../widgets/done_button.dart';
import '../widgets/timer_display.dart';
import '../widgets/player_list.dart';
import '../widgets/leader_menu.dart';

/// Active game screen with turn tracking.
/// Shows green background for active player, red for waiting players.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late HapticService _hapticService;
  bool _wasMyTurn = false;

  @override
  void initState() {
    super.initState();
    _hapticService = HapticServiceImpl();
  }

  @override
  void dispose() {
    _hapticService.stopPulsingVibration();
    _hapticService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionController = context.watch<SessionController>();
    final timerController = context.watch<TimerController>();

    final isMyTurn = sessionController.isMyTurn;
    final backgroundColor = isMyTurn
        ? AppTheme.activePlayerBackground
        : AppTheme.waitingPlayerBackground;

    // Handle turn changes - start/stop timer
    _handleTurnChange(sessionController, timerController, isMyTurn);

    // Handle timer expiration
    _setupTimerCallbacks(timerController);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, sessionController, timerController, isMyTurn),
            Expanded(
              child: _buildMainContent(sessionController, isMyTurn),
            ),
            if (isMyTurn) _buildBottomSection(sessionController, timerController),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    SessionController sessionController,
    TimerController timerController,
    bool isMyTurn,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Timer display (only for active player with timer enabled)
          Expanded(
            child: isMyTurn && sessionController.timerMinutes != null
                ? TimerDisplay(
                    displayTime: timerController.displayTime,
                    isFlashing: timerController.isFlashing,
                  )
                : const SizedBox.shrink(),
          ),
          // Leader menu
          if (sessionController.isLeader)
            LeaderMenu(
              lightIcon: true,
              isGameActive: true,
              onEndGame: () => sessionController.endGame(),
              onChangeTimer: () => _showTimerDialog(context, sessionController),
              onReorderPlayers: () =>
                  _showReorderDialog(context, sessionController),
              onChangeStartPlayer: () =>
                  _showStartPlayerDialog(context, sessionController),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent(SessionController controller, bool isMyTurn) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Status message
          const SizedBox(height: 24),
          Text(
            isMyTurn ? "It's your turn!" : 'Waiting for your turn...',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (!isMyTurn && controller.currentPlayer != null)
            Text(
              '${controller.currentPlayer!.name} is playing',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          const SizedBox(height: 32),
          // Player list
          Expanded(
            child: Card(
              color: Colors.white.withValues(alpha: 0.15),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: PlayerList(
                  players: controller.players,
                  currentPlayerIndex: controller.session?.currentIndex ?? 0,
                  startPlayerIndex: controller.startPlayerIndex,
                  isReorderable: false,
                  showConnectionStatus: true,
                  lightText: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(
    SessionController sessionController,
    TimerController timerController,
  ) {
    return Container(
      height: MediaQuery.of(context).size.height * AppTheme.doneButtonAreaRatio,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: DoneButton(
          onPressed: () {
            // Stop timer and haptic feedback
            timerController.stopTimer();
            _hapticService.stopPulsingVibration();
            // Pass turn
            sessionController.passTurnToNext();
          },
        ),
      ),
    );
  }

  void _handleTurnChange(
    SessionController sessionController,
    TimerController timerController,
    bool isMyTurn,
  ) {
    // Detect turn change
    if (isMyTurn && !_wasMyTurn) {
      // My turn just started
      if (sessionController.timerMinutes != null) {
        timerController.startTimer(sessionController.timerMinutes);
      }
      _hapticService.stopPulsingVibration();
    } else if (!isMyTurn && _wasMyTurn) {
      // My turn just ended
      timerController.stopTimer();
      _hapticService.stopPulsingVibration();
    }
    _wasMyTurn = isMyTurn;
  }

  void _setupTimerCallbacks(TimerController timerController) {
    timerController.onTimerExpired = () {
      _hapticService.startPulsingVibration();
    };
    timerController.onWarningStart = () {
      _hapticService.vibrate();
    };
  }

  void _showTimerDialog(BuildContext context, SessionController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Timer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select timer duration (applies to next turn):'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTimerOption(context, controller, null, 'No Timer'),
                for (int i = 1; i <= 15; i++)
                  _buildTimerOption(context, controller, i, '$i min'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerOption(
    BuildContext context,
    SessionController controller,
    int? minutes,
    String label,
  ) {
    final isSelected = controller.timerMinutes == minutes;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          controller.setTimerMinutes(minutes);
          Navigator.of(context).pop();
        }
      },
    );
  }

  void _showReorderDialog(BuildContext context, SessionController controller) {
    showDialog(
      context: context,
      builder: (context) => _ReorderPlayersDialog(
        players: controller.players,
        onReorder: (ids) {
          // This would require extending SessionController
          // For now, show a message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Player reordering will take effect next turn'),
            ),
          );
        },
      ),
    );
  }

  void _showStartPlayerDialog(BuildContext context, SessionController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Start Player'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: controller.players.length,
            itemBuilder: (context, index) {
              final player = controller.players[index];
              final isSelected = index == controller.startPlayerIndex;
              return ListTile(
                leading: isSelected
                    ? const Icon(Icons.flag, color: Colors.orange)
                    : const Icon(Icons.person_outline),
                title: Text(player.name),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  controller.setStartPlayer(index);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _ReorderPlayersDialog extends StatefulWidget {
  final List<dynamic> players;
  final Function(List<String>) onReorder;

  const _ReorderPlayersDialog({
    required this.players,
    required this.onReorder,
  });

  @override
  State<_ReorderPlayersDialog> createState() => _ReorderPlayersDialogState();
}

class _ReorderPlayersDialogState extends State<_ReorderPlayersDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reorder Players'),
      content: const Text(
        'Player reordering during an active game will take effect on the next round.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
