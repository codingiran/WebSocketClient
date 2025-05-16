//
//  WebSocketEvent.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation
import Starscream

public enum WebSocketEvent: Sendable {
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
}
