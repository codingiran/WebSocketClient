//
//  WebSocketBackend.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

/// WebSocketClientBackend protocol
public protocol WebSocketClientBackend: AnyObject, Sendable {
    func connect(request: URLRequest) async
    func disconnect(closeCode: WebSocketClientCloseCode, reason: String?) async
    func write(frame: WebSocketClientFrame) async throws
    var eventStream: AsyncStream<WebSocketClientEvent> { get }
}
