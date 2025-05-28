//
//  WebSocketFrame.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

/// WebSocketClient Frame
public enum WebSocketClientFrame: Sendable {
    case ping
    case text(String)
    case data(Data)
}

extension WebSocketClientFrame: CustomStringConvertible {
    public var description: String {
        switch self {
        case .ping: return "ping"
        case .text: return "text"
        case .data: return "data"
        }
    }
}
