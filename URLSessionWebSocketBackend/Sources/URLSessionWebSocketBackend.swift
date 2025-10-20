//
//  URLSessionWebSocketBackend.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/23.
//

import Foundation
import WebSocketClient

public final class URLSessionWebSocketBackend: NSObject, @unchecked Sendable {
    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?

    private var eventContinuation: AsyncStream<WebSocketClientEvent>.Continuation?
    private var onReceiveTask: Task<Void, Never>?

    override public init() {
        super.init()
    }

    deinit {
        invalidateUrlSession()
        cancelWebSocketTask()
        cancelOnReceiveTask()
        clearContinuation()
    }
}

// MARK: - WebSocketClientBackend Implementation

extension URLSessionWebSocketBackend: WebSocketClientBackend {
    public func connect(request: URLRequest) async {
        // cancel previous onReceiveTask
        cancelOnReceiveTask()

        // invalidate previous url session
        invalidateUrlSession()

        // create new url session
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        urlSession = session

        // cancel previous webSocketTask
        cancelWebSocketTask()

        // create new webSocketTask
        let urlSessionWebSocketTask = session.webSocketTask(with: request)
        onReceiveTask = Task { [weak self] in
            guard let self else { return }
            await receiveWebSocket(urlSessionWebSocketTask)
        }
        urlSessionWebSocketTask.resume()
        webSocketTask = urlSessionWebSocketTask
    }

    public func disconnect(closeCode: WebSocketClientCloseCode, reason: String?) async {
        // cancel webSocketTask
        cancelWebSocketTask(closeCode: closeCode, reason: reason)

        // invalidate url session to break the retain cycle
        invalidateUrlSession()
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
        AsyncStream { [weak self] continuation in
            continuation.onTermination = { [weak self] _ in
                self?.clearContinuation()
            }
            self?.eventContinuation = continuation
        }
    }
}

// MARK: - Receive WebSocket

private extension URLSessionWebSocketBackend {
    func receiveWebSocket(_ webSocket: URLSessionWebSocketTask) async {
        do {
            if Task.isCancelled { return }
            let message = try await webSocket.receive()
            if Task.isCancelled { return }
            switch message {
            case let .string(text): didReceive(event: .text(text))
            case let .data(data): didReceive(event: .data(data))
            @unknown default: break
            }
            if Task.isCancelled { return }
            await receiveWebSocket(webSocket)
        } catch {
            if Task.isCancelled { return }
            didReceive(event: .error(error))
            cancelOnReceiveTask()
        }
    }

    func didReceive(event: WebSocketClientEvent) {
        guard let _ = webSocketTask else { return }
        guard let eventContinuation: AsyncStream<WebSocketClientEvent>.Continuation else { return }
        eventContinuation.yield(event)
    }
}

// MARK: - URLSessionWebSocketDelegate

extension URLSessionWebSocketBackend: URLSessionWebSocketDelegate {
    public func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didOpenWithProtocol p: String?) {
        var map: [String: String] = [:]
        if let p { map["Sec-WebSocket-Protocol"] = p }
        didReceive(event: .connected(map))
    }

    public func urlSession(_: URLSession, webSocketTask _: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonText: String? = {
            guard let reason = reason else { return nil }
            return String(data: reason, encoding: .utf8)
        }()
        didReceive(event: .disconnected(reasonText, .init(closeCode: closeCode)))
        cancelOnReceiveTask()
    }
}

// MARK: - Clean Up

private extension URLSessionWebSocketBackend {
    func clearContinuation() {
        eventContinuation = nil
    }

    func cancelOnReceiveTask() {
        guard let onReceiveTask else { return }
        onReceiveTask.cancel()
        self.onReceiveTask = nil
    }

    func invalidateUrlSession() {
        guard let urlSession else { return }
        urlSession.invalidateAndCancel()
        self.urlSession = nil
    }

    func cancelWebSocketTask(closeCode: WebSocketClientCloseCode? = nil, reason: String? = nil) {
        guard let webSocketTask else { return }
        if let closeCode {
            webSocketTask.cancel(with: .init(closeCode: closeCode), reason: reason?.data(using: .utf8))
        } else {
            webSocketTask.cancel()
        }
        self.webSocketTask = nil
    }
}
