//
//  WebSocketDelegate.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/20.
//

import Foundation
import Network
#if swift(>=6.0)
    public import WebSocketClientCore
#else
    @_exported import WebSocketClientCore
#endif

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
        func webSocketClient(_ client: WebSocketClient, didMonitorNetworkPathChange path: NWPath)
    }
}

/// Default implementation
public extension WebSocketClient.Delegate {
    func webSocketClient(_: WebSocketClient, didUpdate _: WebSocketClientStatus) {}
    func webSocketClient(_: WebSocketClient, didReceive _: WebSocketClientEvent) {}
    func webSocketClient(_: WebSocketClient, didOutput _: WebSocketClientLog) {}
    func webSocketClientDidSendAutoPing(_: WebSocketClient) {}
    func webSocketClientWillTryReconnect(_: WebSocketClient, forReason _: WebSocketClient.ReconnectReason, afterDelay _: TimeInterval) {}
    func webSocketClientDidTryReconnect(_: WebSocketClient, forReason _: WebSocketClient.ReconnectReason, withAttemptCount _: UInt) {}
    func webSocketClient(_: WebSocketClient, didMonitorNetworkPathChange _: NWPath) {}
}
