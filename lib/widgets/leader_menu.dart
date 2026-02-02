import 'package:flutter/material.dart';

/// Menu system for the team leader.
/// Provides options for game management (end game, change timer, reorder players, etc.)
class LeaderMenu extends StatelessWidget {
  final VoidCallback onEndGame;
  final VoidCallback onChangeTimer;
  final VoidCallback onReorderPlayers;
  final VoidCallback onChangeStartPlayer;
  final bool isGameActive;
  final bool lightIcon;

  const LeaderMenu({
    super.key,
    required this.onEndGame,
    required this.onChangeTimer,
    required this.onReorderPlayers,
    required this.onChangeStartPlayer,
    this.isGameActive = false,
    this.lightIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.menu,
        color: lightIcon ? Colors.white : null,
      ),
      onSelected: (value) => _handleSelection(context, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'change_timer',
          child: ListTile(
            leading: Icon(Icons.timer),
            title: Text('Change Timer'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'reorder_players',
          child: ListTile(
            leading: Icon(Icons.swap_vert),
            title: Text('Reorder Players'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'change_start_player',
          child: ListTile(
            leading: Icon(Icons.flag),
            title: Text('Change Start Player'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        // Disabled future features
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            leading: Icon(Icons.pause, color: Colors.grey[400]),
            title: Text(
              'Pause Game',
              style: TextStyle(color: Colors.grey[400]),
            ),
            subtitle: Text(
              'Coming Soon',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            leading: Icon(Icons.person_remove, color: Colors.grey[400]),
            title: Text(
              'Remove Player',
              style: TextStyle(color: Colors.grey[400]),
            ),
            subtitle: Text(
              'Coming Soon',
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'end_game',
          child: ListTile(
            leading: Icon(Icons.stop_circle, color: Colors.red),
            title: Text('End Game', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _handleSelection(BuildContext context, String value) {
    switch (value) {
      case 'end_game':
        _showEndGameConfirmation(context);
        break;
      case 'change_timer':
        onChangeTimer();
        break;
      case 'reorder_players':
        onReorderPlayers();
        break;
      case 'change_start_player':
        onChangeStartPlayer();
        break;
    }
  }

  void _showEndGameConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Game?'),
        content: const Text(
          'Are you sure you want to end the game? '
          'All players will see the time summary.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onEndGame();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('End Game'),
          ),
        ],
      ),
    );
  }
}

/// Dialog for changing timer settings
class TimerSettingsDialog extends StatefulWidget {
  final int? currentMinutes;
  final Function(int?) onTimerChanged;

  const TimerSettingsDialog({
    super.key,
    this.currentMinutes,
    required this.onTimerChanged,
  });

  @override
  State<TimerSettingsDialog> createState() => _TimerSettingsDialogState();
}

class _TimerSettingsDialogState extends State<TimerSettingsDialog> {
  late int? _selectedMinutes;

  @override
  void initState() {
    super.initState();
    _selectedMinutes = widget.currentMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Timer Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Set turn timer (minutes):'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTimerChip(null, 'No Timer'),
              for (int i = 1; i <= 15; i++) _buildTimerChip(i, '$i min'),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onTimerChanged(_selectedMinutes);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTimerChip(int? minutes, String label) {
    final isSelected = _selectedMinutes == minutes;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedMinutes = minutes);
        }
      },
    );
  }
}

/// Dialog for selecting start player
class StartPlayerDialog extends StatelessWidget {
  final List<String> playerNames;
  final int currentStartIndex;
  final Function(int) onStartPlayerChanged;

  const StartPlayerDialog({
    super.key,
    required this.playerNames,
    required this.currentStartIndex,
    required this.onStartPlayerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Start Player'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: playerNames.length,
          itemBuilder: (context, index) {
            final isSelected = index == currentStartIndex;
            return ListTile(
              leading: isSelected
                  ? const Icon(Icons.flag, color: Colors.orange)
                  : const Icon(Icons.person_outline),
              title: Text(playerNames[index]),
              trailing: isSelected
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                onStartPlayerChanged(index);
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
    );
  }
}

/// Dialog for reordering players
class ReorderPlayersDialog extends StatefulWidget {
  final List<String> playerNames;
  final List<String> playerIds;
  final Function(List<String>) onReorder;

  const ReorderPlayersDialog({
    super.key,
    required this.playerNames,
    required this.playerIds,
    required this.onReorder,
  });

  @override
  State<ReorderPlayersDialog> createState() => _ReorderPlayersDialogState();
}

class _ReorderPlayersDialogState extends State<ReorderPlayersDialog> {
  late List<_PlayerItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.generate(
      widget.playerNames.length,
      (i) => _PlayerItem(widget.playerIds[i], widget.playerNames[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reorder Players'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ReorderableListView.builder(
          itemCount: _items.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final item = _items.removeAt(oldIndex);
              _items.insert(newIndex, item);
            });
          },
          itemBuilder: (context, index) {
            return ListTile(
              key: ValueKey(_items[index].id),
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(_items[index].name),
              trailing: const Icon(Icons.drag_handle),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onReorder(_items.map((i) => i.id).toList());
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _PlayerItem {
  final String id;
  final String name;
  _PlayerItem(this.id, this.name);
}
