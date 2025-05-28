//
//  WebSocketStatus.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

/// An enum representing the status of a WebSocket connection.
public enum WebSocketClientStatus: Sendable {
    /// The WebSocket is in the process of connecting.
    case connecting
    /// The WebSocket is connected and ready to send and receive messages.
    case connected
    /// The WebSocket is closed. The associated value indicates the closure state.
    case closed(state: WebSocketClientStatus.ClosureState)
}

public extension WebSocketClientStatus {
    /// Whether the WebSocket is in a connected status.
    var isConnected: Bool {
        switch self {
        case .connected: return true
        default: return false
        }
    }

    /// Whether the WebSocket is in a connecting status.
    var isConnecting: Bool {
        switch self {
        case .connecting: return true
        default: return false
        }
    }

    /// Whether the WebSocket is in a closed status.
    var isClosed: Bool {
        switch self {
        case .closed: return true
        default: return false
        }
    }

    /// Whether the WebSocket is closed normally.
    var isNormalClosed: Bool {
        switch self {
        case let .closed(state): return state.isNormal
        default: return false
        }
    }

    /// Whether the WebSocket is closed abnormally.
    var isAbnormalClosed: Bool {
        switch self {
        case let .closed(state): return state.isAbnormal
        default: return false
        }
    }
}

extension WebSocketClientStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .connecting: return "connecting"
        case .connected: return "connected"
        case let .closed(state): return state.isNormal ? "normalClosed" : "abnormalClosed"
        }
    }
}

extension WebSocketClientStatus: Equatable {
    public static func == (lhs: WebSocketClientStatus, rhs: WebSocketClientStatus) -> Bool {
        switch (lhs, rhs) {
        case (.connecting, .connecting): return true
        case (.connected, .connected): return true
        case let (.closed(lhsState), .closed(rhsState)): return lhsState == rhsState
        default: return false
        }
    }
}

/// An enum representing the closure state of a WebSocket connection.

public extension WebSocketClientStatus {
    enum ClosureState: Sendable, Equatable {
        /// The WebSocket was closed normally.
        case normal
        /// The WebSocket was closed abnormally.
        case abnormal

        public static func == (lhs: WebSocketClientStatus.ClosureState, rhs: WebSocketClientStatus.ClosureState) -> Bool {
            switch (lhs, rhs) {
            case (.normal, .normal): return true
            case (.abnormal, .abnormal): return true
            default: return false
            }
        }

        public var isNormal: Bool {
            switch self {
            case .normal: return true
            case .abnormal: return false
            }
        }

        public var isAbnormal: Bool {
            switch self {
            case .normal: return false
            case .abnormal: return true
            }
        }
    }
}
