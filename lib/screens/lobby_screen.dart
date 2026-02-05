import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import '../controllers/session_controller.dart';
import '../services/p2p_service.dart';
import '../theme/app_theme.dart';
import 'qr_scanner_screen.dart';

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

  final List<DiscoveredSession> _discoveredSessions = [];
  StreamSubscription<DiscoveredSession>? _discoverySubscription;
  bool _isDiscovering = false;
  SessionController? _sessionController;

  // WiFi network info
  String? _wifiSSID;
  String? _wifiIP;
  final _networkInfo = NetworkInfo();

  @override
  void initState() {
    super.initState();
    // Defer discovery start to after first frame when context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionController = context.read<SessionController>();
      _fetchWifiInfo();
      if (_isNativePlatform) {
        _startDiscovery();
      }
    });
  }

  Future<void> _fetchWifiInfo() async {
    try {
      final ssid = await _networkInfo.getWifiName();
      final ip = await _networkInfo.getWifiIP();
      if (mounted) {
        setState(() {
          // Remove quotes that some platforms add around SSID
          _wifiSSID = ssid?.replaceAll('"', '');
          _wifiIP = ip;
        });
      }
    } catch (e) {
      print('[Lobby] Failed to get WiFi info: $e');
    }
  }

  Widget _buildWifiNetworkInfo() {
    final hasWifi = _wifiSSID != null && _wifiSSID!.isNotEmpty;
    final ssidDisplay = hasWifi ? _wifiSSID! : 'Not connected';
    final ipDisplay = _wifiIP ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: hasWifi ? Colors.blue.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasWifi ? Colors.blue.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasWifi ? Icons.wifi : Icons.wifi_off,
            size: 18,
            color: hasWifi ? Colors.blue.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Network: $ssidDisplay',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: hasWifi ? Colors.blue.shade800 : Colors.red.shade800,
                  ),
                ),
                if (hasWifi)
                  Text(
                    'IP: $ipDisplay',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade600,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: 18,
              color: hasWifi ? Colors.blue.shade700 : Colors.red.shade700,
            ),
            onPressed: _fetchWifiInfo,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Refresh WiFi info',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _leaderNameController.dispose();
    _playerNameController.dispose();
    _sessionCodeController.dispose();
    // Cancel subscription without setState during dispose
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    _sessionController?.stopDiscovery();
    super.dispose();
  }

  bool get _isNativePlatform => Platform.isIOS || Platform.isAndroid;

  void _startDiscovery() {
    final controller = _sessionController;
    if (controller == null) return;

    controller.startDiscovery();
    setState(() => _isDiscovering = true);

    _discoverySubscription = controller.discoveredSessions.listen((session) {
      if (!mounted) return;
      setState(() {
        // Update existing or add new
        final existingIndex = _discoveredSessions.indexWhere(
          (s) => s.code == session.code,
        );
        if (existingIndex >= 0) {
          _discoveredSessions[existingIndex] = session;
        } else {
          _discoveredSessions.add(session);
        }
      });
    });
  }

  void _stopDiscovery() {
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    _sessionController?.stopDiscovery();
    if (mounted) {
      setState(() => _isDiscovering = false);
    }
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
              _buildWifiRequirementNote(),
              const SizedBox(height: 16),
              _buildCreateSection(context),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              if (_isNativePlatform) ...[
                _buildDiscoveredSessionsSection(context),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
              ],
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

  Widget _buildDiscoveredSessionsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nearby Sessions',
                    style: AppTheme.sectionHeader,
                  ),
                ),
                if (_isDiscovering)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // WiFi network info for troubleshooting
            _buildWifiNetworkInfo(),
            const SizedBox(height: 8),
            Text(
              _discoveredSessions.isEmpty
                  ? 'Searching for nearby sessions...'
                  : 'Tap a session to join.',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (_discoveredSessions.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.wifi_tethering, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No sessions found nearby',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ask the host to create a session',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_discoveredSessions.length, (index) {
                final session = _discoveredSessions[index];
                return Padding(
                  padding: EdgeInsets.only(top: index > 0 ? 8 : 0),
                  child: _buildSessionTile(session),
                );
              }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isDiscovering
                  ? _stopDiscovery
                  : _startDiscovery,
              icon: Icon(_isDiscovering ? Icons.stop : Icons.refresh),
              label: Text(_isDiscovering ? 'Stop Scanning' : 'Scan Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(DiscoveredSession session) {
    final isInProgress = session.isInProgress;

    return Material(
      color: isInProgress ? Colors.orange.shade50 : Colors.green.shade50,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isInProgress
            ? null
            : () => _joinDiscoveredSession(session),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isInProgress ? Colors.orange : Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    session.code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hosted by ${session.advertisedBy}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      isInProgress ? 'Game in progress' : 'Open to join',
                      style: TextStyle(
                        fontSize: 12,
                        color: isInProgress ? Colors.orange.shade700 : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isInProgress)
                const Icon(Icons.chevron_right, color: Colors.green),
            ],
          ),
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
            Text(
              _isNativePlatform
                  ? 'Scan the QR code or enter the session code manually.'
                  : 'Enter the session code to join an existing game.',
              style: const TextStyle(color: Colors.black54),
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
            // QR Code scan button (only on mobile)
            if (_isNativePlatform) ...[
              OutlinedButton.icon(
                onPressed: _isJoining ? null : _scanQRCode,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: TextStyle(color: Colors.black54)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _sessionCodeController,
              decoration: const InputDecoration(
                labelText: 'Session Code',
                hintText: 'e.g., ABC-1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
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

  // Stores connection info from QR code scan for direct connection
  String? _qrConnectionInfo;

  Future<void> _scanQRCode() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );

    if (result != null && mounted) {
      final code = result['code'];
      _qrConnectionInfo = result['connectionInfo'];

      if (code != null && code.isNotEmpty) {
        _sessionCodeController.text = code;
        // Auto-join if we have a name
        if (_playerNameController.text.trim().isNotEmpty) {
          _joinSession(context);
        }
      }
    }
  }

  Widget _buildWifiRequirementNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.wifi,
            color: Colors.orange.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Same WiFi Network Required',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All players must be connected to the same WiFi network. '
                  'This is the current method for cross-platform support.',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    final isNative = _isNativePlatform;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isNative
                  ? 'Using WiFi for peer-to-peer connectivity. '
                    'All devices must be on the same network. '
                    'Sessions broadcast via UDP on port 41234.'
                  : 'Running in simulator mode. '
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
    _stopDiscovery(); // Stop discovery when creating

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

  Future<void> _joinDiscoveredSession(DiscoveredSession session) async {
    // Prompt for name if not already entered
    String name = _playerNameController.text.trim();
    if (name.isEmpty) {
      name = await _promptForName() ?? '';
      if (name.isEmpty) return;
      _playerNameController.text = name;
    }

    setState(() => _isJoining = true);
    _stopDiscovery(); // Stop discovery when joining

    try {
      final controller = context.read<SessionController>();
      await controller.joinSession(session.code, name);
    } catch (e) {
      if (mounted) {
        _showError('Failed to join session: $e');
        // Restart discovery on failure
        if (_isNativePlatform) {
          _startDiscovery();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Future<String?> _promptForName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Your Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Your name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
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
    _stopDiscovery(); // Stop discovery when joining

    try {
      final controller = context.read<SessionController>();
      // Use connectionInfo from QR code if available for direct connection
      await controller.joinSession(
        code,
        name,
        connectionInfo: _qrConnectionInfo,
      );
      // Clear connection info after use
      _qrConnectionInfo = null;
    } catch (e) {
      if (mounted) {
        _showError('Failed to join session: $e');
        // Restart discovery on failure
        if (_isNativePlatform) {
          _startDiscovery();
        }
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
