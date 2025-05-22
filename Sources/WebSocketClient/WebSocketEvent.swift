//
//  WebSocketEvent.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

/// WebSocketClient Event
public extension WebSocketClient {
    enum Event: Sendable {
        case connected([String: String])
        case disconnected(String, URLSessionWebSocketTask.CloseCode)
        case text(String)
        case binary(Data)
        case pong(Data?)
        case ping(Data?)
        case error(Error?)
        case viabilityChanged(Bool)
        case reconnectSuggested(Bool)
        case cancelled
        case peerClosed
    }
}

// MARK: - WebsocketClient State

public extension WebSocketClient.Event {
    /// Check if the websocket is connected.
    var isConnected: Bool {
        switch self {
        case .connected, .text, .binary, .ping, .pong, .viabilityChanged, .reconnectSuggested:
            return true
        default:
            return false
        }
    }

    /// Check if the websocket is closed abnormally.
    var isAbnormalClosed: Bool {
        switch self {
        case .cancelled, .error, .peerClosed:
            return true
        case let .disconnected(_, closeCode):
            return closeCode.isAbnormalClosed
        default:
            return false
        }
    }

    /// Check if the websocket is suggesting a reconnect.
    var isReconnectSuggested: Bool {
        switch self {
        case let .reconnectSuggested(suggested):
            return suggested
        default:
            return false
        }
    }

    /// The state of the websocket client.
    var state: WebSocketClient.State {
        isConnected ? .connected : .closed(normalClosure: isAbnormalClosed)
    }
}

// MARK: - StringConvertible

extension WebSocketClient.Event: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .connected:
            return "connected"
        case .disconnected:
            return "disconnected"
        case .text:
            return "text"
        case .binary:
            return "binary"
        case .pong:
            return "pong"
        case .ping:
            return "ping"
        case .error:
            return "error"
        case .viabilityChanged:
            return "viabilityChanged"
        case .reconnectSuggested:
            return "reconnectSuggested"
        case .cancelled:
            return "cancelled"
        case .peerClosed:
            return "peerClosed"
        }
    }

    public var debugDescription: String {
        switch self {
        case let .connected(dictionary):
            return "Connected with headers: \(dictionary)"
        case let .disconnected(string, closeCode):
            return "Disconnected: \(string), Code: \(closeCode)"
        case let .text(string):
            return "Received text: \(string)"
        case let .binary(data):
            return "Received binary: \(data)"
        case .pong:
            return "Received pong"
        case .ping:
            return "Received ping"
        case let .error(error):
            return "Error occurred: \(error?.localizedDescription ?? "Unknown error")"
        case let .viabilityChanged(bool):
            return "Viability changed: \(bool)"
        case let .reconnectSuggested(bool):
            return "Reconnect suggested: \(bool)"
        case .cancelled:
            return "Cancelled"
        case .peerClosed:
            return "Peer closed"
        }
    }
}

#if canImport(Starscream)

    import Starscream

    // MARK: - Parse from Starscream

    extension WebSocketClient.Event {
        init(event: Starscream.WebSocketEvent) {
            switch event {
            case let .connected(headers):
                self = .connected(headers)
            case let .disconnected(reason, code):
                self = .disconnected(reason, .init(rawValue: Int(code)) ?? .invalid)
            case let .text(string):
                self = .text(string)
            case let .binary(data):
                self = .binary(data)
            case let .pong(data):
                self = .pong(data)
            case let .ping(data):
                self = .ping(data)
            case let .error(error):
                self = .error(error)
            case let .viabilityChanged(viability):
                self = .viabilityChanged(viability)
            case let .reconnectSuggested(suggested):
                self = .reconnectSuggested(suggested)
            case .cancelled:
                self = .cancelled
            case .peerClosed:
                self = .peerClosed
            }
        }
    }

#endif
