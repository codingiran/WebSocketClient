//
//  WebSocketBackend.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

/// WebSocketClientBackend protocol
public protocol WebSocketClientBackend: AnyObject, Sendable {
    /// Connect to the WebSocket server with the given request.
    func connect(request: URLRequest) async

    /// Disconnect from the WebSocket server with the specified close code and reason.
    func disconnect(closeCode: WebSocketClientCloseCode, reason: String?) async

    /// Write a frame to the WebSocket server.
    func write(frame: WebSocketClientFrame) async throws

    /// Asynchronous stream of WebSocket client events.
    var eventStream: AsyncStream<WebSocketClientEvent> { get }
}
