package com.tendimensions.yourturn

import android.content.Context
import android.util.Log
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.*
import org.json.JSONArray
import org.json.JSONObject
import java.nio.charset.StandardCharsets

/**
 * Handles Nearby Connections P2P communication for YourTurn app.
 * Manages session advertising, discovery, and message passing.
 */
class P2PHandler(private val context: Context) {

    companion object {
        private const val TAG = "P2PHandler"
        private const val SERVICE_ID = "com.tendimensions.yourturn.p2p"
    }

    // Nearby Connections client
    private val connectionsClient: ConnectionsClient = Nearby.getConnectionsClient(context)

    // Session state
    private var currentSessionId: String? = null
    private var currentSessionCode: String? = null
    private var myPlayerName: String? = null
    private var isHost: Boolean = false
    private var seqNo: Int = 0

    // Connected endpoints (endpointId -> playerName)
    private val connectedEndpoints: MutableMap<String, String> = mutableMapOf()

    // Discovered sessions (endpointId -> session info)
    private val discoveredSessions: MutableMap<String, Map<String, String>> = mutableMapOf()

    // Pending join completion
    private var pendingJoinCallback: ((Result<Map<String, Any>>) -> Unit)? = null
    private var pendingJoinEndpointId: String? = null

    // Event handlers (set by MainActivity)
    var onSessionDiscovered: ((Map<String, Any>) -> Unit)? = null
    var onPeerConnected: ((String, String) -> Unit)? = null
    var onPeerDisconnected: ((String) -> Unit)? = null
    var onMessageReceived: ((Map<String, Any>) -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    // Connection lifecycle callbacks
    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
            Log.d(TAG, "Connection initiated with: ${info.endpointName}")
            // Auto-accept all connections
            connectionsClient.acceptConnection(endpointId, payloadCallback)
        }

        override fun onConnectionResult(endpointId: String, result: ConnectionResolution) {
            when (result.status.statusCode) {
                ConnectionsStatusCodes.STATUS_OK -> {
                    Log.d(TAG, "Connected to endpoint: $endpointId")

                    // If we're joining and this is the host we connected to
                    if (pendingJoinCallback != null && pendingJoinEndpointId == endpointId) {
                        val callback = pendingJoinCallback
                        pendingJoinCallback = null
                        pendingJoinEndpointId = null

                        callback?.invoke(Result.success(mapOf(
                            "sessionId" to (currentSessionId ?: ""),
                            "sessionCode" to (currentSessionCode ?: ""),
                            "playerId" to (myPlayerName ?: ""),
                            "success" to true
                        )))
                    }

                    // Notify about connection
                    val playerName = connectedEndpoints[endpointId] ?: endpointId
                    onPeerConnected?.invoke(playerName, currentSessionId ?: "")

                    // If we're host, send current state to new peer
                    if (isHost) {
                        sendCurrentState(endpointId)
                    }
                }
                ConnectionsStatusCodes.STATUS_CONNECTION_REJECTED -> {
                    Log.d(TAG, "Connection rejected by: $endpointId")
                    pendingJoinCallback?.invoke(Result.failure(Exception("Connection rejected")))
                    pendingJoinCallback = null
                }
                ConnectionsStatusCodes.STATUS_ERROR -> {
                    Log.e(TAG, "Connection error with: $endpointId")
                    pendingJoinCallback?.invoke(Result.failure(Exception("Connection error")))
                    pendingJoinCallback = null
                }
            }
        }

        override fun onDisconnected(endpointId: String) {
            Log.d(TAG, "Disconnected from endpoint: $endpointId")
            val playerName = connectedEndpoints.remove(endpointId) ?: endpointId
            onPeerDisconnected?.invoke(playerName)
        }
    }

    // Payload callback for receiving messages
    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            if (payload.type == Payload.Type.BYTES) {
                payload.asBytes()?.let { bytes ->
                    try {
                        val json = String(bytes, StandardCharsets.UTF_8)
                        val message = jsonToMap(JSONObject(json))
                        onMessageReceived?.invoke(message)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to parse message", e)
                    }
                }
            }
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
            // Not needed for byte payloads
        }
    }

    // Endpoint discovery callback
    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
            Log.d(TAG, "Found endpoint: $endpointId, name: ${info.endpointName}")

            // Parse endpoint name as JSON containing session info
            try {
                val sessionInfo = JSONObject(info.endpointName)
                val infoMap = mapOf(
                    "sessionId" to sessionInfo.optString("sessionId", ""),
                    "sessionCode" to sessionInfo.optString("sessionCode", ""),
                    "leaderName" to sessionInfo.optString("leaderName", ""),
                    "isInProgress" to sessionInfo.optString("isInProgress", "false")
                )
                discoveredSessions[endpointId] = infoMap

                onSessionDiscovered?.invoke(mapOf(
                    "code" to infoMap["sessionCode"]!!,
                    "advertisedBy" to infoMap["leaderName"]!!,
                    "isInProgress" to (infoMap["isInProgress"] == "true")
                ))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to parse endpoint info", e)
            }
        }

        override fun onEndpointLost(endpointId: String) {
            Log.d(TAG, "Lost endpoint: $endpointId")
            discoveredSessions.remove(endpointId)
        }
    }

    // MARK: - Public Methods

    /**
     * Create a new session as host
     */
    fun createSession(leaderName: String, sessionId: String, sessionCode: String): Map<String, Any> {
        cleanup()

        myPlayerName = leaderName
        currentSessionId = sessionId
        currentSessionCode = sessionCode
        isHost = true
        seqNo = 0

        // Create endpoint name as JSON with session info
        val endpointName = JSONObject().apply {
            put("sessionId", sessionId)
            put("sessionCode", sessionCode)
            put("leaderName", leaderName)
            put("isInProgress", "false")
        }.toString()

        // Start advertising
        val advertisingOptions = AdvertisingOptions.Builder()
            .setStrategy(Strategy.P2P_STAR)
            .build()

        connectionsClient.startAdvertising(
            endpointName,
            SERVICE_ID,
            connectionLifecycleCallback,
            advertisingOptions
        ).addOnSuccessListener {
            Log.d(TAG, "Started advertising session: $sessionCode")
        }.addOnFailureListener { e ->
            Log.e(TAG, "Failed to start advertising", e)
            onError?.invoke("Failed to start advertising: ${e.message}")
        }

        return mapOf(
            "sessionId" to sessionId,
            "sessionCode" to sessionCode,
            "leaderId" to leaderName,
            "success" to true
        )
    }

    /**
     * Start discovering nearby sessions
     */
    fun startDiscovery() {
        val discoveryOptions = DiscoveryOptions.Builder()
            .setStrategy(Strategy.P2P_STAR)
            .build()

        connectionsClient.startDiscovery(
            SERVICE_ID,
            endpointDiscoveryCallback,
            discoveryOptions
        ).addOnSuccessListener {
            Log.d(TAG, "Started discovery")
        }.addOnFailureListener { e ->
            Log.e(TAG, "Failed to start discovery", e)
            onError?.invoke("Failed to start discovery: ${e.message}")
        }
    }

    /**
     * Stop discovering sessions
     */
    fun stopDiscovery() {
        connectionsClient.stopDiscovery()
    }

    /**
     * Join an existing session by code
     */
    fun joinSession(sessionCode: String, playerName: String, callback: (Result<Map<String, Any>>) -> Unit) {
        // Find the endpoint with matching session code
        val entry = discoveredSessions.entries.find { it.value["sessionCode"] == sessionCode }

        if (entry == null) {
            callback(Result.failure(Exception("Session not found")))
            return
        }

        val (endpointId, info) = entry

        cleanup()

        myPlayerName = playerName
        currentSessionId = info["sessionId"]
        currentSessionCode = sessionCode
        isHost = false

        pendingJoinCallback = callback
        pendingJoinEndpointId = endpointId

        // Store the endpoint as a connected player
        connectedEndpoints[endpointId] = info["leaderName"] ?: "Host"

        // Request connection to the host
        connectionsClient.requestConnection(
            playerName,
            endpointId,
            connectionLifecycleCallback
        ).addOnFailureListener { e ->
            Log.e(TAG, "Failed to request connection", e)
            pendingJoinCallback?.invoke(Result.failure(e))
            pendingJoinCallback = null
        }
    }

    /**
     * Start the game (update advertising info)
     */
    fun startGame() {
        if (!isHost) return

        // Stop and restart advertising with updated info
        connectionsClient.stopAdvertising()

        val endpointName = JSONObject().apply {
            put("sessionId", currentSessionId ?: "")
            put("sessionCode", currentSessionCode ?: "")
            put("leaderName", myPlayerName ?: "")
            put("isInProgress", "true")
        }.toString()

        val advertisingOptions = AdvertisingOptions.Builder()
            .setStrategy(Strategy.P2P_STAR)
            .build()

        connectionsClient.startAdvertising(
            endpointName,
            SERVICE_ID,
            connectionLifecycleCallback,
            advertisingOptions
        )

        // Broadcast game start to all peers
        broadcast(mapOf(
            "type" to "gameStart",
            "sessionId" to (currentSessionId ?: ""),
            "seqNo" to incrementSeqNo()
        ))
    }

    /**
     * End the game
     */
    fun endGame() {
        broadcast(mapOf(
            "type" to "gameEnd",
            "sessionId" to (currentSessionId ?: ""),
            "seqNo" to incrementSeqNo()
        ))
    }

    /**
     * Pass turn to next player
     */
    fun passTurn(toPlayerId: String, fromPlayerId: String) {
        broadcast(mapOf(
            "type" to "turnChange",
            "sessionId" to (currentSessionId ?: ""),
            "toPlayerId" to toPlayerId,
            "fromPlayerId" to fromPlayerId,
            "seqNo" to incrementSeqNo()
        ))
    }

    /**
     * Update timer settings
     */
    fun updateTimerSetting(minutes: Int?) {
        broadcast(mapOf(
            "type" to "timerUpdate",
            "sessionId" to (currentSessionId ?: ""),
            "minutes" to (minutes ?: JSONObject.NULL),
            "seqNo" to incrementSeqNo()
        ))
    }

    /**
     * Update start player
     */
    fun updateStartPlayer(index: Int) {
        broadcast(mapOf(
            "type" to "startPlayerUpdate",
            "sessionId" to (currentSessionId ?: ""),
            "startPlayerIndex" to index,
            "seqNo" to incrementSeqNo()
        ))
    }

    /**
     * Reorder players
     */
    fun reorderPlayers(playerIds: List<String>) {
        broadcast(mapOf(
            "type" to "playersReorder",
            "sessionId" to (currentSessionId ?: ""),
            "playerIds" to playerIds,
            "seqNo" to incrementSeqNo()
        ))
    }

    /**
     * Leave the current session
     */
    fun leaveSession() {
        broadcast(mapOf(
            "type" to "playerLeft",
            "sessionId" to (currentSessionId ?: ""),
            "playerId" to (myPlayerName ?: ""),
            "seqNo" to incrementSeqNo()
        ))
        cleanup()
    }

    /**
     * Clean up all resources
     */
    fun cleanup() {
        connectionsClient.stopAdvertising()
        connectionsClient.stopDiscovery()
        connectionsClient.stopAllEndpoints()

        connectedEndpoints.clear()
        discoveredSessions.clear()
        currentSessionId = null
        currentSessionCode = null
        isHost = false
        pendingJoinCallback = null
        pendingJoinEndpointId = null
    }

    // MARK: - Private Methods

    private fun incrementSeqNo(): Int {
        seqNo += 1
        return seqNo
    }

    private fun broadcast(message: Map<String, Any>) {
        if (connectedEndpoints.isEmpty()) return

        try {
            val json = mapToJson(message).toString()
            val payload = Payload.fromBytes(json.toByteArray(StandardCharsets.UTF_8))

            for (endpointId in connectedEndpoints.keys) {
                connectionsClient.sendPayload(endpointId, payload)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to broadcast message", e)
            onError?.invoke("Failed to broadcast: ${e.message}")
        }
    }

    private fun sendToEndpoint(endpointId: String, message: Map<String, Any>) {
        try {
            val json = mapToJson(message).toString()
            val payload = Payload.fromBytes(json.toByteArray(StandardCharsets.UTF_8))
            connectionsClient.sendPayload(endpointId, payload)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send message", e)
            onError?.invoke("Failed to send: ${e.message}")
        }
    }

    private fun sendCurrentState(endpointId: String) {
        // Host sends current session state to newly connected peer
        val playerNames = connectedEndpoints.values.toMutableList()
        playerNames.add(0, myPlayerName ?: "")

        sendToEndpoint(endpointId, mapOf(
            "type" to "sessionState",
            "sessionId" to (currentSessionId ?: ""),
            "players" to playerNames,
            "seqNo" to seqNo
        ))
    }

    // JSON conversion helpers
    private fun mapToJson(map: Map<String, Any>): JSONObject {
        val json = JSONObject()
        for ((key, value) in map) {
            when (value) {
                is List<*> -> json.put(key, JSONArray(value))
                is Map<*, *> -> json.put(key, mapToJson(value as Map<String, Any>))
                else -> json.put(key, value)
            }
        }
        return json
    }

    private fun jsonToMap(json: JSONObject): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        for (key in json.keys()) {
            val value = json.get(key)
            map[key] = when (value) {
                is JSONObject -> jsonToMap(value)
                is JSONArray -> jsonArrayToList(value)
                JSONObject.NULL -> ""
                else -> value
            }
        }
        return map
    }

    private fun jsonArrayToList(array: JSONArray): List<Any> {
        val list = mutableListOf<Any>()
        for (i in 0 until array.length()) {
            val value = array.get(i)
            list.add(when (value) {
                is JSONObject -> jsonToMap(value)
                is JSONArray -> jsonArrayToList(value)
                else -> value
            })
        }
        return list
    }
}
