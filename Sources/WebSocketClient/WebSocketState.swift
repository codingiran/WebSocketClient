//
//  WebSocketState.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

/// A simple enum representing the state of a WebSocket connection.

public extension WebSocketClient {
    enum State: Sendable {
        /// The WebSocket is in the process of connecting.
        case connecting
        /// The WebSocket is connected and ready to send and receive messages.
        case connected
        /// The WebSocket is closed. The associated value indicates whether the closure was normal.
        case closed(normalClosure: Bool)
    }
}

public extension WebSocketClient.State {
    /// Whether the WebSocket is in a connected state.
    var isConnected: Bool {
        switch self {
        case .connected: return true
        default: return false
        }
    }

    /// Whether the WebSocket is in a connecting state.
    var isConnecting: Bool {
        switch self {
        case .connecting: return true
        default: return false
        }
    }

    /// Whether the WebSocket is in a closed state.
    var isClosed: Bool {
        switch self {
        case .closed: return true
        default: return false
        }
    }

    /// Whether the WebSocket is closed normally.
    var isNormalClosed: Bool {
        switch self {
        case let .closed(normalClosure): return normalClosure
        default: return false
        }
    }

    /// Whether the WebSocket is closed abnormally.
    var isAbnormalClosed: Bool {
        switch self {
        case let .closed(normalClosure): return !normalClosure
        default: return false
        }
    }
}

extension WebSocketClient.State: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connecting: return "connecting"
        case .connected: return "connected"
        case let .closed(normalClosure): return normalClosure ? "normalClosed" : "abnormalClosed"
        }
    }
}

extension WebSocketClient.State: Equatable {
    public static func == (lhs: WebSocketClient.State, rhs: WebSocketClient.State) -> Bool {
        switch (lhs, rhs) {
        case (.connecting, .connecting): return true
        case (.connected, .connected): return true
        case let (.closed(lhsNormal), .closed(rhsNormal)): return lhsNormal == rhsNormal
        default: return false
        }
    }
}
