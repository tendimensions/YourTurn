package com.tendimensions.yourturn

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "yourturn/p2p"
        private const val EVENT_CHANNEL = "yourturn/p2p_events"
    }

    private var p2pHandler: P2PHandler? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize P2P handler
        p2pHandler = P2PHandler(this)

        // Set up event handlers
        p2pHandler?.onSessionDiscovered = { info ->
            sendEvent(mapOf("type" to "sessionDiscovered", "data" to info))
        }

        p2pHandler?.onPeerConnected = { playerId, sessionId ->
            sendEvent(mapOf(
                "type" to "peerConnected",
                "playerId" to playerId,
                "sessionId" to sessionId
            ))
        }

        p2pHandler?.onPeerDisconnected = { playerId ->
            sendEvent(mapOf(
                "type" to "peerDisconnected",
                "playerId" to playerId
            ))
        }

        p2pHandler?.onMessageReceived = { message ->
            sendEvent(mapOf("type" to "message", "data" to message))
        }

        p2pHandler?.onError = { error ->
            sendEvent(mapOf("type" to "error", "message" to error))
        }

        // Set up method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                handleMethodCall(call.method, call.arguments as? Map<String, Any>, result)
            }

        // Set up event channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun handleMethodCall(
        method: String,
        arguments: Map<String, Any>?,
        result: MethodChannel.Result
    ) {
        val handler = p2pHandler
        if (handler == null) {
            result.error("NOT_INITIALIZED", "P2P handler not initialized", null)
            return
        }

        when (method) {
            "createSession" -> {
                val leaderName = arguments?.get("leaderName") as? String
                val sessionId = arguments?.get("sessionId") as? String
                val sessionCode = arguments?.get("sessionCode") as? String

                if (leaderName == null || sessionId == null || sessionCode == null) {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                    return
                }

                val response = handler.createSession(leaderName, sessionId, sessionCode)
                result.success(response)
            }

            "startDiscovery" -> {
                handler.startDiscovery()
                result.success(null)
            }

            "stopDiscovery" -> {
                handler.stopDiscovery()
                result.success(null)
            }

            "joinSession" -> {
                val sessionCode = arguments?.get("sessionCode") as? String
                val playerName = arguments?.get("playerName") as? String

                if (sessionCode == null || playerName == null) {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                    return
                }

                handler.joinSession(sessionCode, playerName) { joinResult ->
                    mainHandler.post {
                        joinResult.onSuccess { data ->
                            result.success(data)
                        }.onFailure { error ->
                            result.error("JOIN_FAILED", error.message, null)
                        }
                    }
                }
            }

            "startGame" -> {
                handler.startGame()
                result.success(null)
            }

            "endGame" -> {
                handler.endGame()
                result.success(null)
            }

            "passTurn" -> {
                val toPlayerId = arguments?.get("toPlayerId") as? String
                val fromPlayerId = arguments?.get("fromPlayerId") as? String

                if (toPlayerId == null || fromPlayerId == null) {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                    return
                }

                handler.passTurn(toPlayerId, fromPlayerId)
                result.success(null)
            }

            "updateTimerSetting" -> {
                val minutes = arguments?.get("minutes") as? Int
                handler.updateTimerSetting(minutes)
                result.success(null)
            }

            "updateStartPlayer" -> {
                val index = arguments?.get("startPlayerIndex") as? Int
                if (index == null) {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                    return
                }
                handler.updateStartPlayer(index)
                result.success(null)
            }

            "reorderPlayers" -> {
                @Suppress("UNCHECKED_CAST")
                val playerIds = arguments?.get("playerIds") as? List<String>
                if (playerIds == null) {
                    result.error("INVALID_ARGS", "Missing arguments", null)
                    return
                }
                handler.reorderPlayers(playerIds)
                result.success(null)
            }

            "leaveSession" -> {
                handler.leaveSession()
                result.success(null)
            }

            "cleanup" -> {
                handler.cleanup()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun sendEvent(event: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(event)
        }
    }

    override fun onDestroy() {
        p2pHandler?.cleanup()
        super.onDestroy()
    }
}
