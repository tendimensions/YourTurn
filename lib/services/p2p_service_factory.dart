// Factory for creating platform-specific P2P service implementations.
import 'dart:io' show Platform;
import 'p2p_service.dart';
import 'p2p_service_stub.dart';
import 'p2p_service_ios.dart';
import 'p2p_service_android.dart';
import 'p2p_service_wifi.dart';

/// P2P connectivity mode
enum P2PMode {
  /// WiFi-based TCP/IP (cross-platform, requires same WiFi network)
  wifi,

  /// Platform-native (iOS MultipeerConnectivity / Android Nearby Connections)
  /// Note: Does NOT support cross-platform (iOS <-> Android)
  platformNative,

  /// In-memory stub for testing/development
  stub,
}

/// Current default P2P mode.
/// WiFi mode is the default for cross-platform support.
const P2PMode defaultP2PMode = P2PMode.wifi;

/// Creates the appropriate P2PService implementation based on mode and platform.
///
/// [mode] - The P2P connectivity mode to use. Defaults to [defaultP2PMode].
///
/// **WiFi mode** (default): Uses TCP/IP sockets for cross-platform connectivity.
/// All devices must be on the same WiFi network. This is the recommended mode
/// for mixed iOS/Android groups.
///
/// **Platform-native mode**: Uses MultipeerConnectivity (iOS) or Nearby Connections
/// (Android). Better performance but does NOT support cross-platform communication.
/// Use only when all players have the same device type.
///
/// **Stub mode**: In-memory implementation for testing/development.
P2PService createP2PService({P2PMode mode = defaultP2PMode}) {
  switch (mode) {
    case P2PMode.wifi:
      if (Platform.isIOS || Platform.isAndroid) {
        return WifiP2PService();
      }
      // Fall through to stub for non-mobile platforms
      return InMemoryP2PService();

    case P2PMode.platformNative:
      if (Platform.isIOS) {
        return IOsP2PService();
      }
      if (Platform.isAndroid) {
        return AndroidP2PService();
      }
      // Fall through to stub for non-mobile platforms
      return InMemoryP2PService();

    case P2PMode.stub:
      return InMemoryP2PService();
  }
}

/// Creates a WiFi-based P2P service for cross-platform connectivity.
/// Requires all devices to be on the same WiFi network.
P2PService createWifiP2PService() => createP2PService(mode: P2PMode.wifi);

/// Creates a platform-native P2P service.
/// Does NOT support cross-platform (iOS <-> Android).
P2PService createNativeP2PService() =>
    createP2PService(mode: P2PMode.platformNative);
