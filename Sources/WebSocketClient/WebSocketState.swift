//
//  WebSocketState.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

/// A simple enum representing the state of a WebSocket connection.
public enum WebSocketState: String, Sendable {
    case connecting
    case connected
    case closed
    case failed
}
