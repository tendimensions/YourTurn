import Foundation
import MultipeerConnectivity

/// Handles MultipeerConnectivity P2P communication for YourTurn app.
/// Manages session advertising, browsing, and message passing.
class P2PHandler: NSObject {

    // MARK: - Constants
    private static let serviceType = "yourturn-game" // Max 15 chars, lowercase alphanumeric and hyphens

    // MARK: - Properties
    private var peerID: MCPeerID!
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var currentSessionId: String?
    private var currentSessionCode: String?
    private var isHost: Bool = false
    private var seqNo: Int = 0

    // Event handlers (set by AppDelegate)
    var onSessionDiscovered: (([String: Any]) -> Void)?
    var onPeerConnected: ((String, String) -> Void)?
    var onPeerDisconnected: ((String) -> Void)?
    var onMessageReceived: (([String: Any]) -> Void)?
    var onError: ((String) -> Void)?

    // Track discovered sessions
    private var discoveredPeers: [MCPeerID: [String: String]] = [:]

    // Track connected players
    private var connectedPlayers: [MCPeerID: [String: Any]] = [:]

    // Pending join state
    private var pendingJoinCompletion: ((Result<[String: Any], Error>) -> Void)?
    private var pendingJoinHostPeer: MCPeerID?
    private var joinTimeoutTimer: Timer?

    // MARK: - Initialization
    override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// Create a new session as host
    func createSession(leaderName: String, sessionId: String, sessionCode: String) -> [String: Any] {
        cleanup()

        peerID = MCPeerID(displayName: leaderName)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        currentSessionId = sessionId
        currentSessionCode = sessionCode
        isHost = true
        seqNo = 0

        // Start advertising with session info
        let discoveryInfo: [String: String] = [
            "sessionId": sessionId,
            "sessionCode": sessionCode,
            "leaderName": leaderName,
            "isInProgress": "false"
        ]

        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: P2PHandler.serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        print("[P2P] Created session: \(sessionCode) as \(leaderName)")

        return [
            "sessionId": sessionId,
            "sessionCode": sessionCode,
            "leaderId": peerID.displayName,
            "success": true
        ]
    }

    /// Start browsing for nearby sessions
    func startDiscovery() {
        // Create a temporary peer ID for browsing if we don't have one
        if peerID == nil {
            peerID = MCPeerID(displayName: "Browser-\(UUID().uuidString.prefix(4))")
        }

        browser?.stopBrowsingForPeers()
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: P2PHandler.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()

        print("[P2P] Started discovery")
    }

    /// Stop browsing for sessions
    func stopDiscovery() {
        browser?.stopBrowsingForPeers()
        // Don't nil the browser yet - we might need it for joining
        print("[P2P] Stopped discovery")
    }

    /// Join an existing session
    func joinSession(sessionCode: String, playerName: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        print("[P2P] Attempting to join session: \(sessionCode) as \(playerName)")

        // Find the peer with matching session code
        guard let (hostPeer, info) = discoveredPeers.first(where: { $0.value["sessionCode"] == sessionCode }) else {
            print("[P2P] Session not found in discovered peers. Available: \(discoveredPeers.values.map { $0["sessionCode"] ?? "?" })")
            completion(.failure(NSError(domain: "P2P", code: 404, userInfo: [NSLocalizedDescriptionKey: "Session not found. Try scanning again."])))
            return
        }

        // Store info before cleanup
        let sessionId = info["sessionId"] ?? ""

        // Stop advertising/browsing but keep discovered peers
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        session?.disconnect()
        session = nil

        // Create new peer identity for joining
        peerID = MCPeerID(displayName: playerName)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self

        currentSessionId = sessionId
        currentSessionCode = sessionCode
        isHost = false

        // Store completion to call when connected
        pendingJoinCompletion = completion
        pendingJoinHostPeer = hostPeer

        // Set up timeout
        joinTimeoutTimer?.invalidate()
        joinTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.handleJoinTimeout()
        }

        // Re-create browser with new peer ID and invite the host
        browser?.stopBrowsingForPeers()
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: P2PHandler.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()

        // Small delay to let browser initialize, then invite
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, let session = self.session else { return }
            print("[P2P] Sending invitation to host: \(hostPeer.displayName)")
            self.browser?.invitePeer(hostPeer, to: session, withContext: playerName.data(using: .utf8), timeout: 30)
        }
    }

    private func handleJoinTimeout() {
        if let completion = pendingJoinCompletion {
            print("[P2P] Join timed out")
            pendingJoinCompletion = nil
            pendingJoinHostPeer = nil
            completion(.failure(NSError(domain: "P2P", code: 408, userInfo: [NSLocalizedDescriptionKey: "Connection timed out. Please try again."])))
        }
    }

    /// Start the game (update advertising info)
    func startGame() {
        guard isHost else { return }

        advertiser?.stopAdvertisingPeer()

        let discoveryInfo: [String: String] = [
            "sessionId": currentSessionId ?? "",
            "sessionCode": currentSessionCode ?? "",
            "leaderName": peerID.displayName,
            "isInProgress": "true"
        ]

        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: P2PHandler.serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        // Broadcast game start to all peers
        broadcast(message: [
            "type": "gameStart",
            "sessionId": currentSessionId ?? "",
            "seqNo": incrementSeqNo()
        ])
    }

    /// End the game
    func endGame() {
        broadcast(message: [
            "type": "gameEnd",
            "sessionId": currentSessionId ?? "",
            "seqNo": incrementSeqNo()
        ])
    }

    /// Pass turn to next player
    func passTurn(toPlayerId: String, fromPlayerId: String) {
        broadcast(message: [
            "type": "turnChange",
            "sessionId": currentSessionId ?? "",
            "toPlayerId": toPlayerId,
            "fromPlayerId": fromPlayerId,
            "seqNo": incrementSeqNo()
        ])
    }

    /// Update timer settings
    func updateTimerSetting(minutes: Int?) {
        broadcast(message: [
            "type": "timerUpdate",
            "sessionId": currentSessionId ?? "",
            "minutes": minutes as Any,
            "seqNo": incrementSeqNo()
        ])
    }

    /// Update start player
    func updateStartPlayer(index: Int) {
        broadcast(message: [
            "type": "startPlayerUpdate",
            "sessionId": currentSessionId ?? "",
            "startPlayerIndex": index,
            "seqNo": incrementSeqNo()
        ])
    }

    /// Reorder players
    func reorderPlayers(playerIds: [String]) {
        broadcast(message: [
            "type": "playersReorder",
            "sessionId": currentSessionId ?? "",
            "playerIds": playerIds,
            "seqNo": incrementSeqNo()
        ])
    }

    /// Leave the current session
    func leaveSession() {
        broadcast(message: [
            "type": "playerLeft",
            "sessionId": currentSessionId ?? "",
            "playerId": peerID?.displayName ?? "",
            "seqNo": incrementSeqNo()
        ])
        cleanup()
    }

    /// Clean up all resources
    func cleanup() {
        joinTimeoutTimer?.invalidate()
        joinTimeoutTimer = nil
        pendingJoinCompletion = nil
        pendingJoinHostPeer = nil

        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session?.disconnect()
        session = nil
        currentSessionId = nil
        currentSessionCode = nil
        isHost = false
        connectedPlayers.removeAll()
        discoveredPeers.removeAll()
        peerID = nil
    }

    // MARK: - Private Methods

    private func incrementSeqNo() -> Int {
        seqNo += 1
        return seqNo
    }

    private func broadcast(message: [String: Any]) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }

        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            onError?("Failed to broadcast: \(error.localizedDescription)")
        }
    }

    private func send(message: [String: Any], to peer: MCPeerID) {
        guard let session = session else { return }

        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            try session.send(data, toPeers: [peer], with: .reliable)
        } catch {
            onError?("Failed to send: \(error.localizedDescription)")
        }
    }
}

// MARK: - MCSessionDelegate
extension P2PHandler: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch state {
            case .connected:
                print("[P2P] Peer connected: \(peerID.displayName)")

                // Cancel timeout timer
                self.joinTimeoutTimer?.invalidate()
                self.joinTimeoutTimer = nil

                // If we're joining and this is the host
                if let completion = self.pendingJoinCompletion {
                    self.pendingJoinCompletion = nil
                    self.pendingJoinHostPeer = nil

                    completion(.success([
                        "sessionId": self.currentSessionId ?? "",
                        "sessionCode": self.currentSessionCode ?? "",
                        "playerId": self.peerID.displayName,
                        "success": true
                    ]))
                }

                // Notify about connection
                self.onPeerConnected?(peerID.displayName, self.currentSessionId ?? "")

                // If we're host, send current state to new peer
                if self.isHost {
                    self.sendCurrentState(to: peerID)
                }

            case .notConnected:
                print("[P2P] Peer disconnected: \(peerID.displayName)")
                self.connectedPlayers.removeValue(forKey: peerID)
                self.onPeerDisconnected?(peerID.displayName)

                // If we were trying to join and got disconnected
                if let completion = self.pendingJoinCompletion {
                    self.pendingJoinCompletion = nil
                    self.pendingJoinHostPeer = nil
                    self.joinTimeoutTimer?.invalidate()
                    self.joinTimeoutTimer = nil
                    completion(.failure(NSError(domain: "P2P", code: 500, userInfo: [NSLocalizedDescriptionKey: "Connection failed. Please try again."])))
                }

            case .connecting:
                print("[P2P] Connecting to peer: \(peerID.displayName)")

            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onMessageReceived?(message)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used
    }

    private func sendCurrentState(to peer: MCPeerID) {
        // Host sends current session state to newly connected peer
        let connectedPlayerNames = (session?.connectedPeers.map { $0.displayName } ?? []) + [peerID.displayName]

        send(message: [
            "type": "sessionState",
            "sessionId": currentSessionId ?? "",
            "players": connectedPlayerNames,
            "seqNo": seqNo
        ], to: peer)
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension P2PHandler: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Accept all invitations (players joining the session)
        print("[P2P] Received invitation from: \(peerID.displayName)")

        // Store player info from context
        if let context = context, let playerName = String(data: context, encoding: .utf8) {
            connectedPlayers[peerID] = ["name": playerName, "id": peerID.displayName]
        }

        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("[P2P] Failed to start advertising: \(error.localizedDescription)")
        onError?("Failed to start advertising: \(error.localizedDescription)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension P2PHandler: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("[P2P] Found peer: \(peerID.displayName) with info: \(info ?? [:])")

        if let info = info {
            discoveredPeers[peerID] = info

            // Notify Flutter about discovered session
            DispatchQueue.main.async { [weak self] in
                self?.onSessionDiscovered?([
                    "code": info["sessionCode"] ?? "",
                    "advertisedBy": info["leaderName"] ?? peerID.displayName,
                    "isInProgress": info["isInProgress"] == "true"
                ])
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("[P2P] Lost peer: \(peerID.displayName)")
        discoveredPeers.removeValue(forKey: peerID)
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("[P2P] Failed to start browsing: \(error.localizedDescription)")
        onError?("Failed to start browsing: \(error.localizedDescription)")
    }
}
