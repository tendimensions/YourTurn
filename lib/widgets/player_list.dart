import 'package:flutter/material.dart';
import '../models.dart';
import 'player_tile.dart';

/// Reusable player list widget.
/// Supports reordering when enabled (for leader in setup/menu).
class PlayerList extends StatelessWidget {
  final List<Player> players;
  final int currentPlayerIndex;
  final int startPlayerIndex;
  final bool isReorderable;
  final bool showConnectionStatus;
  final bool lightText;
  final Function(int, int)? onReorder;
  final Function(int)? onPlayerTap;

  const PlayerList({
    super.key,
    required this.players,
    this.currentPlayerIndex = 0,
    this.startPlayerIndex = 0,
    this.isReorderable = false,
    this.showConnectionStatus = true,
    this.lightText = false,
    this.onReorder,
    this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isReorderable && onReorder != null) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        buildDefaultDragHandles: true,
        itemCount: players.length,
        onReorder: onReorder!,
        proxyDecorator: (child, index, animation) {
          return Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: child,
          );
        },
        itemBuilder: (context, index) {
          return _buildPlayerCard(context, index);
        },
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: players.length,
      itemBuilder: (context, index) {
        return _buildPlayerCard(context, index);
      },
    );
  }

  Widget _buildPlayerCard(BuildContext context, int index) {
    final player = players[index];
    final isCurrent = index == currentPlayerIndex;
    final isStart = index == startPlayerIndex;

    return Card(
      key: ValueKey(player.id),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      color: lightText ? Colors.white.withValues(alpha: 0.15) : null,
      elevation: lightText ? 0 : 1,
      child: PlayerTile(
        player: player,
        isCurrent: isCurrent,
        isStartPlayer: isStart,
        showConnectionStatus: showConnectionStatus,
        lightText: lightText,
        onTap: onPlayerTap != null ? () => onPlayerTap!(index) : null,
      ),
    );
  }
}
