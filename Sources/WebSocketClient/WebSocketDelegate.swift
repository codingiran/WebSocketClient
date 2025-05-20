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
    }
}
