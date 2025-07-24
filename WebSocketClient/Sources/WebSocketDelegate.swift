//
//  WebSocketDelegate.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/20.
//

import Foundation
import NetworkPathMonitor

public extension WebSocketClient {
    protocol Delegate: AnyObject, Sendable {
        /// WebSocket status on change
        func webSocketClient(_ client: WebSocketClient, didUpdate status: WebSocketClientStatus)

        /// WebSocket received a message
        func webSocketClient(_ client: WebSocketClient, didReceive event: WebSocketClientEvent)

        /// WebSocket output log
        func webSocketClient(_ client: WebSocketClient, didOutput log: WebSocketClientLog)

        /// WebSocket will try reconnect
        func webSocketClientWillTryReconnect(_ client: WebSocketClient, forReason reason: WebSocketClient.ReconnectReason, afterDelay interval: TimeInterval)

        /// WebSocket did try reconnect
        func webSocketClientDidTryReconnect(_ client: WebSocketClient, forReason reason: WebSocketClient.ReconnectReason, withAttemptCount attemptCount: UInt)

        /// WebSocket did send auto ping
        func webSocketClientDidSendAutoPing(_ client: WebSocketClient)

        /// WebSocket did monitor network path change
        func webSocketClient(_ client: WebSocketClient, didMonitorNetworkPathChange path: NetworkPath)
    }
}

/// Default implementation
public extension WebSocketClient.Delegate {
    func webSocketClient(_ client: WebSocketClient, didUpdate status: WebSocketClientStatus) {}
    func webSocketClient(_ client: WebSocketClient, didReceive event: WebSocketClientEvent) {}
    func webSocketClient(_ client: WebSocketClient, didOutput log: WebSocketClientLog) {}
    func webSocketClientDidSendAutoPing(_: WebSocketClient) {}
    func webSocketClientWillTryReconnect(_ client: WebSocketClient, forReason reason: WebSocketClient.ReconnectReason, afterDelay interval: TimeInterval) {}
    func webSocketClientDidTryReconnect(_ client: WebSocketClient, forReason reason: WebSocketClient.ReconnectReason, withAttemptCount attemptCount: UInt) {}
    func webSocketClient(_ client: WebSocketClient, didMonitorNetworkPathChange path: NetworkPath) {}
}
