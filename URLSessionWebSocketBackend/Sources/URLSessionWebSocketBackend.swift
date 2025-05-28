//
//  URLSessionWebSocketBackend.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/23.
//

import Foundation
import WebSocketClient

public final class URLSessionWebSocketBackend: NSObject, @unchecked Sendable {
    private var webSocketTask: URLSessionWebSocketTask?

    private var eventContinuation: AsyncStream<WebSocketClientEvent>.Continuation?

    override public init() {
        super.init()
    }
}

extension URLSessionWebSocketBackend: WebSocketClientBackend {
    public func connect(request: URLRequest) async {
        webSocketTask = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            .webSocketTask(with: request)
        Task(priority: .medium) {
            await self.receive()
        }
        webSocketTask?.resume()
    }

    public func disconnect(closeCode: WebSocketClientCloseCode, reason: String?) async {
        guard let task = webSocketTask else { return }
        task.cancel(with: .init(closeCode: closeCode), reason: reason?.data(using: .utf8))
    }

    public func write(frame: WebSocketClientFrame) async throws {
        guard let task = webSocketTask else { return }
        switch frame {
        case let .text(text):
            try await task.send(.string(text))
        case let .data(data):
            try await task.send(.data(data))
        case .ping:
            task.sendPing { [weak self] _ in
                self?.didReceive(event: .pong)
            }
        }
    }

    public var eventStream: AsyncStream<WebSocketClientEvent> {
        AsyncStream { continuation in
            continuation.onTermination = { _ in
                self.clearContinuation()
            }
            self.eventContinuation = continuation
        }
    }
}

private extension URLSessionWebSocketBackend {
    func receive() async {
        guard let task = webSocketTask else { return }
        do {
            let message = try await task.receive()
            switch message {
            case let .string(text): didReceive(event: .text(text))
            case let .data(data): didReceive(event: .data(data))
            @unknown default: break
            }
            await receive()
        } catch {
            didReceive(event: .error(error))
        }
    }

    func didReceive(event: WebSocketClientEvent) {
        guard let eventContinuation: AsyncStream<WebSocketClientEvent>.Continuation else { return }
        eventContinuation.yield(event)
    }

    func clearContinuation() {
        eventContinuation = nil
    }
}

extension URLSessionWebSocketBackend: URLSessionDataDelegate, URLSessionWebSocketDelegate {
    public func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didOpenWithProtocol p: String?) {
        var map: [String: String] = [:]
        if let p {
            map["Sec-WebSocket-Protocol"] = p
        }
        didReceive(event: .connected(map))
    }

    public func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonText: String? = {
            guard let reason = reason else { return nil }
            return String(data: reason, encoding: .utf8)
        }()
        didReceive(event: .disconnected(reasonText, .init(closeCode: closeCode)))
    }

    public func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error else {
            didReceive(event: .disconnected(nil, .normalClosure))
            return
        }
        didReceive(event: .error(error))
    }
}
