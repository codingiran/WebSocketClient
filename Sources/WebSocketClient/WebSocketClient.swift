//
//  WebSocketClient.swift
//  WebSocketClient
//
//  Created by iran.qiu on 2025/05/16.
//

import Foundation
import Network
import Starscream

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.9)
    #error("WebSocketClient doesn't support Swift versions below 5.9")
#endif

public enum WebSocketClientInfo: Sendable {
    /// Current WebSocketClient version.
    public static let version = "0.0.1"
}

public class WebSocketClient: @unchecked Sendable {
    private let urlRequest: URLRequest

    private let pingInterval: TimeInterval

    private let requireNetworkAvailable: Bool

    private let engine: WebSocketEngine

    private let webSocket: WebSocket

    private let networkPath = NetworkPath()

    @WebSocketClientActor
    private var state: WebSocketState = .closed

    private var reconnectCount: UInt = 0

    private var autoPingTimer: AsyncRepeatingTimer?

    public required init(urlRequest: URLRequest,
                         pingInterval: TimeInterval = 0,
                         requireNetworkAvailable: Bool = true,
                         engine: WebSocketEngine = .tcpTransport)
    {
        self.urlRequest = urlRequest
        self.pingInterval = pingInterval
        self.requireNetworkAvailable = requireNetworkAvailable
        self.engine = engine
        self.webSocket = WebSocket(request: urlRequest, useCustomEngine: {
            switch engine {
            case .tcpTransport: return true
            case .urlSession: return false
            }
        }())
    }

    public convenience init(url: URL,
                            cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                            connectionTimeout: TimeInterval = 5,
                            connectionHeader: [String: String],
                            pingInterval: TimeInterval = 0,
                            requireNetworkAvailable: Bool = true,
                            engine: WebSocketEngine = .tcpTransport)
    {
        self.init(urlRequest: .init(url: url, cachePolicy: cachePolicy, timeoutInterval: connectionTimeout, httpHeaders: connectionHeader),
                  pingInterval: pingInterval,
                  requireNetworkAvailable: requireNetworkAvailable,
                  engine: engine)
    }
}

@WebSocketClientActor
public extension WebSocketClient {
    func connect() async {
        if case .connected = state {
            return
        }
        if case .connecting = state {
            return
        }
        if requireNetworkAvailable {
            guard await networkPath.isSatisfied else {
                return
            }
        }
        state = .connecting
        webSocket.forceDisconnect()
        webSocket.delegate = self
        webSocket.connect()
    }

    func disconnect(closeCode: WebSocketCloseCode = .normal) {
        webSocket.disconnect(closeCode: closeCode.rawValue)
    }

    func forceDisconnect() {
        webSocket.forceDisconnect()
    }

    func send(_ frame: WebSocketFrameOpCode) async {
        await withCheckedContinuation { cont in
            switch frame {
            case .pong(let data): webSocket.write(pong: data) { cont.resume() }
            case .ping(let data): webSocket.write(ping: data) { cont.resume() }
            case .text(let string): webSocket.write(string: string) { cont.resume() }
            case .binary(let data): webSocket.write(data: data) { cont.resume() }
            }
        }
    }

    func ping(data: Data = Data()) async {
        await send(.ping(data))
    }

    func pong(data: Data = Data()) async {
        await send(.pong(data))
    }
}

// MARK: - Watch Network

extension WebSocketClient {
    func watchNetworkPath() async {
        for await path in await networkPath.networkPathChanges() {
            guard path.isSatisfied else {
                // Network not available
                debugPrint("Network is not available")
                return
            }
            // Network recovered
        }
    }
}

// MARK: - Ping Pong

private extension WebSocketClient {
    func enableAutoPing() async {
        await disableAutoPing()
        guard pingInterval > 0 else {
            return
        }
        autoPingTimer = AsyncRepeatingTimer(interval: pingInterval) {
            Task { await self.ping() }
        }
    }

    func disableAutoPing() async {
        await autoPingTimer?.stop()
        autoPingTimer = nil
    }
}

// MARK: - Reconnect

private extension WebSocketClient {
    func tryReconnectAfterNetworkRecovery() async {
        guard await networkPath.isSatisfied else { return }
        guard case .failed = await state else { return }
    }

    func reconnect(reason: ReconnectReason) async {
        debugPrint("try reconnect for \(reason.name)")
    }
}

// MARK: - WebSocket Events

@WebSocketClientActor
extension WebSocketClient {
    func receive(event: WebSocketEvent) {}
}

// MARK: - WebSocketDelegate

extension WebSocketClient: WebSocketDelegate {
    public func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            Task { @WebSocketClientActor in self.receive(event: .connected(headers)) }
        case .disconnected(let reason, let code):
            Task { @WebSocketClientActor in self.receive(event: .disconnected(reason, code)) }
        case .text(let string):
            Task { @WebSocketClientActor in self.receive(event: .text(string)) }
        case .binary(let data):
            Task { @WebSocketClientActor in self.receive(event: .binary(data)) }
        case .pong(let data):
            Task { @WebSocketClientActor in self.receive(event: .pong(data)) }
        case .ping(let data):
            Task { @WebSocketClientActor in self.receive(event: .ping(data)) }
        case .error(let error):
            Task { @WebSocketClientActor in self.receive(event: .error(error)) }
        case .viabilityChanged(let viability):
            Task { @WebSocketClientActor in self.receive(event: .viabilityChanged(viability)) }
        case .reconnectSuggested(let suggested):
            Task { @WebSocketClientActor in self.receive(event: .reconnectSuggested(suggested)) }
        case .cancelled:
            Task { @WebSocketClientActor in self.receive(event: .cancelled) }
        case .peerClosed:
            Task { @WebSocketClientActor in self.receive(event: .peerClosed) }
        }
    }
}

private extension WebSocketClient {
    enum ReconnectReason: Sendable {
        case wsOnError(Error)
        case networkRecovery(NWPath)

        var name: String {
            switch self {
            case .wsOnError(let error):
                return "socket error"
            case .networkRecovery(let nWPath):
                return "network recovery"
            }
        }
    }
}

@globalActor
public enum WebSocketClientActor {
    public actor TheActor {}
    public static let shared = TheActor()
}
