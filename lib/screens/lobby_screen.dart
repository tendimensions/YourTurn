import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/session_controller.dart';
import '../theme/app_theme.dart';

/// Lobby screen for creating or joining sessions.
/// Shows session discovery and join options.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _leaderNameController = TextEditingController();
  final _playerNameController = TextEditingController();
  final _sessionCodeController = TextEditingController();
  bool _isCreating = false;
  bool _isJoining = false;

  @override
  void dispose() {
    _leaderNameController.dispose();
    _playerNameController.dispose();
    _sessionCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YourTurn'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCreateSection(context),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              _buildJoinSection(context),
              const SizedBox(height: 24),
              _buildInfoNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create a Session',
              style: AppTheme.sectionHeader,
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a new game session as the team leader.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _leaderNameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter your name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              enabled: !_isCreating,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isCreating ? null : () => _createSession(context),
              icon: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_circle),
              label: Text(_isCreating ? 'Creating...' : 'Create Session'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Join a Session',
              style: AppTheme.sectionHeader,
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the session code to join an existing game.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _playerNameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter your name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
              enabled: !_isJoining,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sessionCodeController,
              decoration: const InputDecoration(
                labelText: 'Session Code',
                hintText: 'e.g., ABC-1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              textCapitalization: TextCapitalization.characters,
              enabled: !_isJoining,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isJoining ? null : () => _joinSession(context),
              icon: _isJoining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.group_add),
              label: Text(_isJoining ? 'Joining...' : 'Join Session'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This version uses an in-memory simulator. '
              'Create a session, then use the displayed code to join from this device.',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createSession(BuildContext context) async {
    final name = _leaderNameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final controller = context.read<SessionController>();
      await controller.createSession(name);
    } catch (e) {
      if (mounted) {
        _showError('Failed to create session: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _joinSession(BuildContext context) async {
    final name = _playerNameController.text.trim();
    final code = _sessionCodeController.text.trim().toUpperCase();

    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    if (code.isEmpty) {
      _showError('Please enter a session code');
      return;
    }

    setState(() => _isJoining = true);

    try {
      final controller = context.read<SessionController>();
      await controller.joinSession(code, name);
    } catch (e) {
      if (mounted) {
        _showError('Failed to join session: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}
