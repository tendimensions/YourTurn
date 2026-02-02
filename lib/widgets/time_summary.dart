import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';

/// Displays the end-game time summary.
/// Shows total green-screen time for each player in list format.
class TimeSummary extends StatelessWidget {
  final List<Player> players;
  final Map<String, Duration> playerTimes;

  const TimeSummary({
    super.key,
    required this.players,
    required this.playerTimes,
  });

  @override
  Widget build(BuildContext context) {
    // Sort players by total time (descending)
    final sortedPlayers = [...players];
    sortedPlayers.sort((a, b) {
      final timeA = playerTimes[a.id] ?? Duration.zero;
      final timeB = playerTimes[b.id] ?? Duration.zero;
      return timeB.compareTo(timeA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Game Summary',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Total time per player',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ...sortedPlayers.map((player) => _buildPlayerRow(player)),
      ],
    );
  }

  Widget _buildPlayerRow(Player player) {
    final time = playerTimes[player.id] ?? Duration.zero;
    final formattedTime = AppTheme.formatDuration(time);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            child: Text(
              player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              player.name,
              style: AppTheme.timeSummaryName,
            ),
          ),
          Text(
            formattedTime,
            style: AppTheme.timeSummaryTime,
          ),
        ],
      ),
    );
  }
}
