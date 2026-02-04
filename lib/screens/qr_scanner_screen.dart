import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// QR code scanner screen for joining sessions.
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.startsWith('yourturn:')) {
        _hasScanned = true;
        final result = _parseQRData(rawValue);
        Navigator.pop(context, result);
        return;
      }
    }
  }

  /// Parses QR data in format: yourturn:CODE or yourturn:CODE:IP:PORT
  /// Returns a Map with 'code' and optionally 'connectionInfo'
  Map<String, String> _parseQRData(String rawValue) {
    // Remove 'yourturn:' prefix
    final data = rawValue.substring(9);

    // Check if it contains connection info (format: CODE:IP:PORT)
    // Session codes are typically short (e.g., ABC-1), so we look for IP:PORT pattern
    final parts = data.split(':');

    if (parts.length >= 3) {
      // Format: CODE:IP:PORT - IP might contain dots, port is numeric
      // Session code is the first part, rest is IP:PORT
      final code = parts[0];
      final connectionInfo = parts.sublist(1).join(':');
      return {
        'code': code,
        'connectionInfo': connectionInfo,
      };
    }

    // Simple format: just CODE
    return {
      'code': data,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay with scanning guide
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: const Text(
                'Point your camera at the QR code displayed on the host\'s device',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [
                    Shadow(blurRadius: 8, color: Colors.black),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
