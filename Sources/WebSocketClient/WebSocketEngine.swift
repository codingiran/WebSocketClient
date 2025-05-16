//
//  WebSocketEngine.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

public enum WebSocketEngine: Sendable {
    // Using TCP NWConnection to implement WebSocket
    case tcpTransport
    // Using URLSessionWebSocketTask to implement WebSocket
    case urlSession
}
