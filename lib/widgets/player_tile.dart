import 'package:flutter/material.dart';
import '../models.dart';

class PlayerTile extends StatelessWidget {
  final Player player;
  final bool isCurrent;
  const PlayerTile({super.key, required this.player, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(player.name.isNotEmpty ? player.name[0].toUpperCase() : '?')),
      title: Text(player.name),
      subtitle: Text(player.id),
      trailing: isCurrent ? const Icon(Icons.play_circle_fill) : null,
    );
  }
}
