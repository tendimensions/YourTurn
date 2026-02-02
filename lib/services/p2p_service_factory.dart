// Factory for creating platform-specific P2P service implementations.
import 'dart:io' show Platform;
import 'p2p_service.dart';
import 'p2p_service_stub.dart';
import 'p2p_service_ios.dart';

/// Creates the appropriate P2PService implementation based on the current platform.
P2PService createP2PService() {
  if (Platform.isIOS) {
    return IOsP2PService();
  }
  // For Android and other platforms, use the stub for now
  // TODO: Implement AndroidP2PService when ready
  return InMemoryP2PService();
}
