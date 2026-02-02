import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';

/// Displays a single player in the player list.
/// Shows connection status dot and current player indicator.
class PlayerTile extends StatelessWidget {
  final Player player;
  final bool isCurrent;
  final bool isStartPlayer;
  final bool showConnectionStatus;
  final bool lightText;
  final VoidCallback? onTap;

  const PlayerTile({
    super.key,
    required this.player,
    this.isCurrent = false,
    this.isStartPlayer = false,
    this.showConnectionStatus = true,
    this.lightText = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _buildLeading(context),
      title: Text(
        player.name,
        style: lightText ? AppTheme.playerNameLight : AppTheme.playerName,
      ),
      trailing: _buildTrailing(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildLeading(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current player indicator (green dot)
        if (isCurrent)
          Container(
            width: AppTheme.currentPlayerDotSize,
            height: AppTheme.currentPlayerDotSize,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: AppTheme.currentPlayerIndicator,
              shape: BoxShape.circle,
            ),
          )
        else
          SizedBox(
            width: AppTheme.currentPlayerDotSize + 8,
          ),
        // Player avatar
        CircleAvatar(
          backgroundColor: lightText
              ? Colors.white.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: lightText ? Colors.white : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrailing() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Start player indicator
        if (isStartPlayer)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.flag,
              size: 20,
              color: lightText ? Colors.white70 : Colors.orange,
            ),
          ),
        // Connection status dot
        if (showConnectionStatus)
          Container(
            width: AppTheme.connectionDotSize,
            height: AppTheme.connectionDotSize,
            decoration: BoxDecoration(
              color: _getConnectionColor(),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  Color _getConnectionColor() {
    switch (player.connectionStatus) {
      case ConnectionStatus.connected:
        return AppTheme.connectionActive;
      case ConnectionStatus.disconnected:
        return AppTheme.connectionInactive;
      case ConnectionStatus.connecting:
        return AppTheme.connectionPending;
    }
  }
}
