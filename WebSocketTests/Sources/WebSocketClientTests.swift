import Network
@testable import StarscreamBackend
@testable import URLSessionWebSocketBackend
@testable import WebSocketClient
@testable import WebSocketCore
import XCTest

final class WebSocketClientTests: XCTestCase, @unchecked Sendable {
    var webSocketClient: WebSocketClient?

    func testURLSessionWebSocketBackend() async throws {
        try await testWebSocket(using: URLSessionWebSocketBackend())
    }

    func testStarscreamBackend() async throws {
        try await testWebSocket(using: StarscreamBackend())
    }

    func testWebSocket(using backend: WebSocketClientBackend) async throws {
        let url = URL(string: "wss://giasstest.ecn.zenlayer.net:8891/zga/ws?userIds=iran.qiu@zenlayer.com_2000003_2000013_315B562A-E0B4-4249-A704-AD20E93C13F8")!
        let headers = [
            "x-token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NTA1NzQ0MDQsImlhdCI6MTc0Nzk4MjQwNCwiaXNzIjoiVHVyYm8gWCBBcGkiLCJuYmYiOjE3NDc5ODE0MDQsIlVVSUQiOiJiMjgxODA0OC0wYjIwLTRkZTEtYTRmYi02Y2MzZDZlZWQ3ZjUiLCJHcm91cElkIjoyMDAwMDEzLCJVc2VyTmFtZSI6ImlyYW4ucWl1QHplbmxheWVyLmNvbSIsIkNvbXBhbnlJZCI6MjAwMDAwMywiY29tcGFueU5hbWUiOiJ0ZXN0X1plbmxheWVyX3ZpcCIsImJ1ZmZlclRpbWUiOjg2NDAwLCJkZXZpY2VDb2RlIjoiMzE1QjU2MkEtRTBCNC00MjQ5LUE3MDQtQUQyMEU5M0MxM0Y4In0.qD9_Sez2e-s-LgXEd3NaLmou8uXHuCHcgm9877E8jZM",
            "x-user-id": "b2818048-0b20-4de1-a4fb-6cc3d6eed7f5",
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
