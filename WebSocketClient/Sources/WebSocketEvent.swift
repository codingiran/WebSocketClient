//
//  WebSocketEvent.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

/// WebSocketClient Event
public enum WebSocketClientEvent: Sendable {
    case connected([String: String])
    case disconnected(String?, WebSocketClientCloseCode)
    case text(String)
    case data(Data)
    case pong
    case error(Error)
}

// MARK: - WebsocketClient Status

public extension WebSocketClientEvent {
    /// Check if the websocket is connected.
    var isConnected: Bool {
        switch self {
        case .connected, .text, .data, .pong:
            return true
        default:
            return false
        }
    }

    /// Check if the websocket is closed abnormally.
    var isAbnormalClosed: Bool {
        switch self {
        case .error:
            return true
        case let .disconnected(_, closeCode):
            return closeCode.isAbnormalClosed
        default:
            return false
        }
    }
}

// MARK: - StringConvertible

extension WebSocketClientEvent: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .connected: return "connected"
        case .disconnected: return "disconnected"
        case .text: return "text"
        case .data: return "data"
        case .pong: return "pong"
        case .error: return "error"
        }
    }

    public var debugDescription: String {
        switch self {
        case let .connected(dictionary): return "connected with headers: \(dictionary)"
        case let .disconnected(reason, closeCode): return "disconnected with close code: \(closeCode), reason: \(reason ?? "")"
        case let .text(string): return "text: \(string)"
        case let .data(data): return "data of \(data.count) bytes"
        case .pong: return "pong"
        case let .error(error): return "error occurred for \(error.localizedDescription)"
        }
    }
}
