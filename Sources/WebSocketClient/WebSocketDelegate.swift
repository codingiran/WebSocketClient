//
//  WebSocketDelegate.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/20.
//

import Foundation

public extension WebSocketClient {
    protocol Delegate: Sendable {
        /// WebSocket state change
        func webSocketClient(_ client: WebSocketClient, didUpdate state: WebSocketClient.State)

        /// WebSocket received a message
        func webSocketClient(_ client: WebSocketClient, didReceive event: WebSocketClient.Event)

        /// WebSocket output log
        func webSocketClient(_ client: WebSocketClient, didOutput log: WebSocketClient.Log)

        /// WebSocket will reconnect
        func webSocketClientWillReconnect(_ client: WebSocketClient, reason: WebSocketClient.ReconnectReason)

        /// WebSocket will send auto ping
        func webSocketClientWillSendAutoPing(_ client: WebSocketClient)

        /// WebSocket did send auto ping
        func webSocketClientDidSendAutoPing(_ client: WebSocketClient)
    }
}

/// Default implementation
public extension WebSocketClient.Delegate {
    func webSocketClient(_: WebSocketClient, didUpdate _: WebSocketClient.State) {}
    func webSocketClient(_: WebSocketClient, didReceive _: WebSocketClient.Event) {}
    func webSocketClient(_: WebSocketClient, didOutput _: WebSocketClient.Log) {}
    func webSocketClientWillReconnect(_: WebSocketClient, reason _: WebSocketClient.ReconnectReason) {}
    func webSocketClientWillSendAutoPing(_: WebSocketClient) {}
    func webSocketClientDidSendAutoPing(_: WebSocketClient) {}
}
