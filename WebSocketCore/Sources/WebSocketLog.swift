//
//  WebSocketLog.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/20.
//

import Foundation

/// WebSocketClient Log
public struct WebSocketClientLog: Sendable {
    public let level: LogLevel
    public let message: String

    public init(level: LogLevel, message: String) {
        self.level = level
        self.message = message
    }
}

public extension WebSocketClientLog {
    enum LogLevel: String, Sendable {
        case verbose
        case debug
        case info
        case warning
        case error
    }
}
