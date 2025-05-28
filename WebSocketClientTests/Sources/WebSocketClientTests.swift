import Network
@testable import URLSessionWebSocketBackend
@testable import WebSocketClient
@testable import WebSocketClientCore
import XCTest

final class WebSocketClientTests: XCTestCase, @unchecked Sendable {
    var webSocketClient: WebSocketClient?

    func testURLSessionWebSocketBackend() async throws {
        try await testWebSocket(using: URLSessionWebSocketBackend())
    }

    func testWebSocket(using backend: WebSocketClientBackend) async throws {
        let url = URL(string: "")!
        let headers = [
            "x-token": "",
            "x-user-id": "",
        ]
        webSocketClient = WebSocketClient(url: url,
                                          connectTimeout: 5,
                                          httpHeaders: headers,
                                          autoPingInterval: 10000,
                                          webSocketBackend: backend,
                                          networkMonitorDebounceInterval: 1.0)
        webSocketClient?.delegate = self
        await webSocketClient?.connect()

        let connectExpectation = expectation(description: "Connected successfully")
        let messageExpectation = expectation(description: "Received message")
        let pingExpectation = expectation(description: "Ping responded")

        let aliveExpectation = expectation(description: "Keep alive")
        aliveExpectation.isInverted = true

        // 等待所有期望
        await fulfillment(
            of: [connectExpectation, messageExpectation, pingExpectation, aliveExpectation],
            timeout: 3600
        )
    }
}

extension WebSocketClientTests: WebSocketClient.Delegate {
    /// WebSocket status on change
    func webSocketClient(_: WebSocketClient, didUpdate status: WebSocketClientStatus) {
        print("WebSocket status: \(status.description)")
    }

    /// WebSocket received a message
    func webSocketClient(_: WebSocketClient, didReceive event: WebSocketClientEvent) {
        print("WebSocket received event: \(event.debugDescription)")
    }

    /// WebSocket output log
    func webSocketClient(_: WebSocketClient, didOutput log: WebSocketClientLog) {
        print("WebSocket log: \(log.message)")
    }

    /// WebSocket will try reconnect
    func webSocketClientWillTryReconnect(_: WebSocketClient, forReason reason: WebSocketClient.ReconnectReason, afterDelay interval: TimeInterval) {
        print("WebSocket will try reconnect for reason: \(reason.description) after delay: \(interval)")
    }

    /// WebSocket did try reconnect
    func webSocketClientDidTryReconnect(_: WebSocketClient, forReason reason: WebSocketClient.ReconnectReason, withAttemptCount attemptCount: UInt) {
        print("WebSocket did try reconnect for reason: \(reason.description) with attempt count: \(attemptCount)")
    }

    /// WebSocket did send auto ping
    func webSocketClientDidSendAutoPing(_: WebSocketClient) {
        print("WebSocket did send auto ping")
    }
}
