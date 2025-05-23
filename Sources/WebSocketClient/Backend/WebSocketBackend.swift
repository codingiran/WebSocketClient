//
//  WebSocketBackend.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

public extension WebSocketClient {
    enum Backend: Sendable {
        // Using URLSessionWebSocketTask to implement WebSocket
        case urlSession
        // Using TCP NWConnection to implement WebSocket
        case tcpTransport
        // Using SwiftNIO to implement WebSocket
        case swiftNIO
    }
}

public extension WebSocketClient {
    protocol Backending: AnyObject, Sendable {
        func connect(request: URLRequest) async
        func disconnect(closeCode: URLSessionWebSocketTask.CloseCode, reason: String?) async
        func write(frame: WebSocketClient.FrameOpCode) async throws
        var eventStream: AsyncStream<WebSocketClient.Event> { get }
    }
}
