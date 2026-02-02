import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var p2pHandler: P2PHandler?
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Set up P2P handler
        setupP2PChannel()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupP2PChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }

        // Initialize P2P handler
        p2pHandler = P2PHandler()

        // Set up event handlers
        p2pHandler?.onSessionDiscovered = { [weak self] info in
            self?.sendEvent(["type": "sessionDiscovered", "data": info])
        }

        p2pHandler?.onPeerConnected = { [weak self] playerId, sessionId in
            self?.sendEvent([
                "type": "peerConnected",
                "playerId": playerId,
                "sessionId": sessionId
            ])
        }

        p2pHandler?.onPeerDisconnected = { [weak self] playerId in
            self?.sendEvent([
                "type": "peerDisconnected",
                "playerId": playerId
            ])
        }

        p2pHandler?.onMessageReceived = { [weak self] message in
            self?.sendEvent(["type": "message", "data": message])
        }

        p2pHandler?.onError = { [weak self] error in
            self?.sendEvent(["type": "error", "message": error])
        }

        // Set up method channel for commands
        methodChannel = FlutterMethodChannel(
            name: "yourturn/p2p",
            binaryMessenger: controller.binaryMessenger
        )

        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }

        // Set up event channel for streaming events
        eventChannel = FlutterEventChannel(
            name: "yourturn/p2p_events",
            binaryMessenger: controller.binaryMessenger
        )

        eventChannel?.setStreamHandler(self)
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let handler = p2pHandler else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "P2P handler not initialized", details: nil))
            return
        }

        switch call.method {
        case "createSession":
            guard let args = call.arguments as? [String: Any],
                  let leaderName = args["leaderName"] as? String,
                  let sessionId = args["sessionId"] as? String,
                  let sessionCode = args["sessionCode"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }
            let response = handler.createSession(leaderName: leaderName, sessionId: sessionId, sessionCode: sessionCode)
            result(response)

        case "startDiscovery":
            handler.startDiscovery()
            result(nil)

        case "stopDiscovery":
            handler.stopDiscovery()
            result(nil)

        case "joinSession":
            guard let args = call.arguments as? [String: Any],
                  let sessionCode = args["sessionCode"] as? String,
                  let playerName = args["playerName"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }
            handler.joinSession(sessionCode: sessionCode, playerName: playerName) { joinResult in
                switch joinResult {
                case .success(let data):
                    result(data)
                case .failure(let error):
                    result(FlutterError(code: "JOIN_FAILED", message: error.localizedDescription, details: nil))
                }
            }

        case "startGame":
            handler.startGame()
            result(nil)

        case "endGame":
            handler.endGame()
            result(nil)

        case "passTurn":
            guard let args = call.arguments as? [String: Any],
                  let toPlayerId = args["toPlayerId"] as? String,
                  let fromPlayerId = args["fromPlayerId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }
            handler.passTurn(toPlayerId: toPlayerId, fromPlayerId: fromPlayerId)
            result(nil)

        case "updateTimerSetting":
            let args = call.arguments as? [String: Any]
            let minutes = args?["minutes"] as? Int
            handler.updateTimerSetting(minutes: minutes)
            result(nil)

        case "updateStartPlayer":
            guard let args = call.arguments as? [String: Any],
                  let index = args["startPlayerIndex"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }
            handler.updateStartPlayer(index: index)
            result(nil)

        case "reorderPlayers":
            guard let args = call.arguments as? [String: Any],
                  let playerIds = args["playerIds"] as? [String] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                return
            }
            handler.reorderPlayers(playerIds: playerIds)
            result(nil)

        case "leaveSession":
            handler.leaveSession()
            result(nil)

        case "cleanup":
            handler.cleanup()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func sendEvent(_ event: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }
}

// MARK: - FlutterStreamHandler
extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
