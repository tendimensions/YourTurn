import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/session_controller.dart';
import 'models.dart';
import 'widgets/player_tile.dart';

void main() {
  runApp(const TurnNotifierApp());
}

class TurnNotifierApp extends StatelessWidget {
  const TurnNotifierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionController(),
      child: MaterialApp(
        title: 'Turn Notifier',
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _leaderName = TextEditingController();
  final _joinName = TextEditingController();
  final _joinCode = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SessionController>();
    final session = ctrl.session;
    return Scaffold(
      appBar: AppBar(title: const Text('Turn Notifier (Skeleton)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: session == null ? _buildLobby(ctrl) : _buildSession(ctrl),
      ),
    );
  }

  Widget _buildLobby(SessionController ctrl) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create a Session (Leader)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _leaderName,
            decoration: const InputDecoration(labelText: 'Your name (leader)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              if (_leaderName.text.trim().isEmpty) return;
              await ctrl.createSession(_leaderName.text.trim());
            },
            icon: const Icon(Icons.playlist_add),
            label: const Text('Create session'),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Join a Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _joinName,
            decoration: const InputDecoration(labelText: 'Your name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _joinCode,
            decoration: const InputDecoration(labelText: 'Session code (e.g., ABC-1)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              if (_joinName.text.trim().isEmpty || _joinCode.text.trim().isEmpty) return;
              await ctrl.joinSession(_joinCode.text.trim(), _joinName.text.trim());
            },
            icon: const Icon(Icons.group_add),
            label: const Text('Join session'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Note: This skeleton uses an in-memory simulator. '
            'Once you create a session here, you can join it using the code shown on the session screen.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildSession(SessionController ctrl) {
    final s = ctrl.session!;
    final players = ctrl.players;
    final current = ctrl.currentPlayer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Session: ${s.code}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (ctrl.isLeader)
              const Chip(label: Text('Leader'))
            else
              const Chip(label: Text('Player')),
          ],
        ),
        const SizedBox(height: 8),
        Text('Current: ${current?.name ?? '-'}'),
        const SizedBox(height: 16),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: ctrl.isLeader,
            itemCount: players.length,
            onReorder: (a, b) {
              if (ctrl.isLeader) ctrl.reorderPlayers(a, b);
            },
            itemBuilder: (ctx, i) {
              final p = players[i];
              return Card(
                key: ValueKey(p.id),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: PlayerTile(player: p, isCurrent: current?.id == p.id),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => ctrl.passTurnToNext(),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Done — pass to next'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'This UI mirrors the intended flow. Replace the stub with a real P2P service '
          '(MultipeerConnectivity on iOS, Nearby Connections or BLE on Android).',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}
