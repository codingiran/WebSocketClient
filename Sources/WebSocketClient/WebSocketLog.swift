//
//  WebSocketLog.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/20.
//

import Foundation

public extension WebSocketClient {
    struct Log: Sendable {
        public let level: Log.LogLevel
        public let message: String

        public init(level: Log.LogLevel, message: String) {
            self.level = level
            self.message = message
        }
    }
}

public extension WebSocketClient.Log {
    enum LogLevel: String, Sendable {
        case verbose
        case debug
        case info
        case warning
        case error
    }
}

extension WebSocketClient {
    func log(_ log: WebSocketClient.Log) {
        delegate?.webSocketClient(self, didOutput: log)
    }

    func verboseLog(_ message: String) {
        log(.init(level: .verbose, message: message))
    }

    func debugLog(_ message: String) {
        log(.init(level: .debug, message: message))
    }

    func infoLog(_ message: String) {
        log(.init(level: .info, message: message))
    }

    func warningLog(_ message: String) {
        log(.init(level: .warning, message: message))
    }

    func errorLog(_ message: String) {
        log(.init(level: .error, message: message))
    }
}
