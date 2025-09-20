# Turn Notifier — Flutter Skeleton

A minimal Flutter project skeleton for a **local, peer-to-peer turn notifier** (tabletop game helper).
This zip contains the **app structure** and a **stubbed P2P service** with clear seams to add native code:

- iOS: MultipeerConnectivity
- Android: Nearby Connections or BLE

> This is a *starter skeleton*, not a production-ready P2P implementation. It compiles once you place it inside a Flutter project.

## Quick start (recommended flow)

1. Ensure you have the Flutter SDK installed.
2. Create a fresh Flutter project (this gives you all platform scaffolding):
   ```bash
   flutter create turn_notifier
   ```
3. Copy the contents of this skeleton **over** the newly created project:
   - Overwrite `pubspec.yaml` and the `lib/` folder from this zip.
   - Optionally review the `android/` and `ios/` notes below for permissions.
4. Install dependencies:
   ```bash
   cd turn_notifier
   flutter pub get
   ```
5. Run:
   ```bash
   flutter run
   ```

You’ll get a working **local simulator** (single-device) for sessions, players, and turn passing. 
The `P2PService` interface is ready for a native-backed implementation when you’re ready.

---

## Where to add real P2P

- **`lib/services/p2p_service.dart`** — Interface & platform switch.
- **`lib/services/p2p_service_stub.dart`** — In-memory simulator (keeps UI functional).
- Add a platform channel to call into:
  - iOS: `MultipeerConnectivity` (Swift; e.g., `MCNearbyServiceAdvertiser`, `MCNearbyServiceBrowser`, `MCSession`).
  - Android: Nearby Connections (`com.google.android.gms.nearby.Nearby.getConnectionsClient`) *or* raw BLE + Wi-Fi Direct.

If you choose platform channels:
- Create a `MethodChannel('turnnotifier/p2p')` on Dart side (already noted in comments).
- iOS: add a Swift file in `ios/Runner/` (e.g., `P2PBridge.swift`) and wire to the same channel name.
- Android: add a Kotlin file in `android/app/src/main/kotlin/.../P2PBridge.kt` and wire to the same channel.

---

## Minimal permissions (add when you implement radios)

### iOS (Info.plist additions)
- `NSBluetoothAlwaysUsageDescription` (string)
- Optional: Background Modes → "Uses Bluetooth LE accessories" if you want limited background scan/advert.
- Optional: `NSLocalNetworkUsageDescription` (if you use local networking).

### Android (AndroidManifest additions)
For Android 12+ (API 31+):
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```
For Android 10–11:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```
If running background scan during a session, consider a foreground service with:
```xml
<service
    android:name=".TurnNotifierService"
    android:foregroundServiceType="connectedDevice" />
```

---

## App structure (overview)

```
lib/
  main.dart                  # App, simple UI for leader & players
  models.dart                # Session, Player models
  controllers/
    session_controller.dart  # State management (Provider/ChangeNotifier)
  services/
    p2p_service.dart         # P2P interface (to be implemented natively later)
    p2p_service_stub.dart    # In-memory simulator (works today)
  widgets/
    player_tile.dart         # Small UI helper
```

## Next steps

- Replace the stub with real P2P:
  - iOS: MultipeerConnectivity (serviceType "turnntf").
  - Android: Nearby Connections (Strategy.P2P_CLUSTER) **or** BLE advert+scan for discovery + short GATT writes for ACKs.
- Add local notifications (e.g., `flutter_local_notifications`) to alert the next player.
- Handle background throttling on iOS and a foreground service on Android during a session.

MIT License. Have fun!
