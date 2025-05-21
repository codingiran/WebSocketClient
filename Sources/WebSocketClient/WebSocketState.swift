//
//  WebSocketState.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

/// A simple enum representing the state of a WebSocket connection.

public extension WebSocketClient {
    enum State: String, Sendable, Equatable {
        case connecting
        case connected
        case closed
    }
}

// MARK: - Parse from event

extension WebSocketClient.State {
    init(event: WebSocketClient.Event) {
        switch event {
        case .connected, .text, .binary, .ping, .pong, .viabilityChanged, .reconnectSuggested:
            self = .connected
        case .disconnected, .error, .cancelled, .peerClosed:
            self = .closed
        }
    }
}
