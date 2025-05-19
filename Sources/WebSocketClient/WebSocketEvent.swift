//
//  WebSocketEvent.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation
import Starscream

public extension WebSocketClient {
    enum Event: Sendable, CustomStringConvertible {
        case connected([String: String])
        case disconnected(String, UInt16)
        case text(String)
        case binary(Data)
        case pong(Data?)
        case ping(Data?)
        case error(Error?)
        case viabilityChanged(Bool)
        case reconnectSuggested(Bool)
        case cancelled
        case peerClosed

        init(event: Starscream.WebSocketEvent) {
            switch event {
            case .connected(let headers):
                self = .connected(headers)
            case .disconnected(let reason, let code):
                self = .disconnected(reason, code)
            case .text(let string):
                self = .text(string)
            case .binary(let data):
                self = .binary(data)
            case .pong(let data):
                self = .pong(data)
            case .ping(let data):
                self = .ping(data)
            case .error(let error):
                self = .error(error)
            case .viabilityChanged(let viability):
                self = .viabilityChanged(viability)
            case .reconnectSuggested(let suggested):
                self = .reconnectSuggested(suggested)
            case .cancelled:
                self = .cancelled
            case .peerClosed:
                self = .peerClosed
            }
        }

        public var description: String {
            switch self {
            case .connected(let dictionary):
                return "connected: \(dictionary)"
            case .disconnected(let string, let uInt16):
                return "disconnected: \(string), code: \(uInt16)"
            case .text(let string):
                return "text: \(string)"
            case .binary:
                return "binary"
            case .pong:
                return "pong"
            case .ping:
                return "ping)"
            case .error(let error):
                return "error for \(error?.localizedDescription ?? "unknown")"
            case .viabilityChanged(let bool):
                return "viabilityChanged \(bool)"
            case .reconnectSuggested(let bool):
                return "reconnectSuggested \(bool)"
            case .cancelled:
                return "cancelled"
            case .peerClosed:
                return "peerClosed"
            }
        }
    }
}
