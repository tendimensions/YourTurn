import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/session_controller.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/player_list.dart';
import '../widgets/leader_menu.dart';

/// Setup screen shown before game starts.
/// Leader can configure timer, reorder players, and start the game.
/// Players see a waiting view with the player list.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Session: ${controller.session?.code ?? ''}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _showLeaveConfirmation(context, controller),
        ),
        actions: [
          if (controller.isLeader)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Leader'),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: controller.isLeader
            ? _buildLeaderView(context, controller)
            : _buildPlayerView(context, controller),
      ),
    );
  }

  Widget _buildLeaderView(BuildContext context, SessionController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSessionInfo(controller),
                const SizedBox(height: 24),
                _buildTimerSection(context, controller),
                const SizedBox(height: 24),
                _buildPlayersSection(context, controller),
                const SizedBox(height: 24),
                _buildTurnFocusSection(context),
              ],
            ),
          ),
        ),
        _buildStartButton(context, controller),
      ],
    );
  }

  Widget _buildPlayerView(BuildContext context, SessionController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSessionInfo(controller),
                const SizedBox(height: 24),
                _buildWaitingInfo(controller),
                const SizedBox(height: 24),
                _buildPlayersSection(context, controller),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionInfo(SessionController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Session Code',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              controller.session?.code ?? '',
              style: AppTheme.sessionCode,
            ),
            const SizedBox(height: 8),
            Text(
              '${controller.players.length}/${Session.maxPlayers} players',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingInfo(SessionController controller) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top, color: Colors.amber),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Waiting for the team leader to start the game...',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerSection(BuildContext context, SessionController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer),
                const SizedBox(width: 8),
                Text('Turn Timer', style: AppTheme.sectionHeader),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              controller.timerMinutes == null
                  ? 'No timer set'
                  : '${controller.timerMinutes} minute${controller.timerMinutes == 1 ? '' : 's'} per turn',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showTimerDialog(context, controller),
              icon: const Icon(Icons.edit),
              label: const Text('Change Timer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersSection(BuildContext context, SessionController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people),
                const SizedBox(width: 8),
                Text('Players', style: AppTheme.sectionHeader),
                const Spacer(),
                if (controller.isLeader)
                  TextButton.icon(
                    onPressed: () => _showStartPlayerDialog(context, controller),
                    icon: const Icon(Icons.flag, size: 18),
                    label: const Text('Start Player'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (controller.isLeader)
              const Text(
                'Drag to reorder turn sequence',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            const SizedBox(height: 12),
            PlayerList(
              players: controller.players,
              currentPlayerIndex: controller.session?.currentIndex ?? 0,
              startPlayerIndex: controller.startPlayerIndex,
              isReorderable: controller.isLeader,
              onReorder: controller.isLeader
                  ? (oldIndex, newIndex) {
                      controller.reorderPlayers(oldIndex, newIndex);
                    }
                  : null,
              onPlayerTap: controller.isLeader
                  ? (index) => controller.setStartPlayer(index)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnFocusSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_locked, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Turn Focus',
                  style: AppTheme.sectionHeader.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: false,
                  onChanged: null, // Disabled
                ),
                const Expanded(
                  child: Text(
                    'Lock phone during other players\' turns',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Coming Soon',
                style: TextStyle(fontSize: 12, color: Colors.amber),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(BuildContext context, SessionController controller) {
    final canStart = controller.canStartGame;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!canStart)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Need at least ${Session.minPlayersToStart} players to start',
                style: const TextStyle(color: Colors.orange),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canStart ? () => controller.startGame() : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Game'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTimerDialog(BuildContext context, SessionController controller) {
    showDialog(
      context: context,
      builder: (context) => TimerSettingsDialog(
        currentMinutes: controller.timerMinutes,
        onTimerChanged: (minutes) => controller.setTimerMinutes(minutes),
      ),
    );
  }

  void _showStartPlayerDialog(BuildContext context, SessionController controller) {
    showDialog(
      context: context,
      builder: (context) => StartPlayerDialog(
        playerNames: controller.players.map((p) => p.name).toList(),
        currentStartIndex: controller.startPlayerIndex,
        onStartPlayerChanged: (index) => controller.setStartPlayer(index),
      ),
    );
  }

  void _showLeaveConfirmation(BuildContext context, SessionController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Session?'),
        content: Text(
          controller.isLeader
              ? 'As the leader, leaving will end the session for all players.'
              : 'Are you sure you want to leave this session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              controller.leaveSession();
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}
