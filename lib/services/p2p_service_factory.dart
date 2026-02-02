// Factory for creating platform-specific P2P service implementations.
import 'dart:io' show Platform;
import 'p2p_service.dart';
import 'p2p_service_stub.dart';
import 'p2p_service_ios.dart';
import 'p2p_service_android.dart';

/// Creates the appropriate P2PService implementation based on the current platform.
P2PService createP2PService() {
  if (Platform.isIOS) {
    return IOsP2PService();
  }
  if (Platform.isAndroid) {
    return AndroidP2PService();
  }
  // For other platforms (desktop, web), use the stub
  return InMemoryP2PService();
}
