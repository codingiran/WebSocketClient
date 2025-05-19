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
    /// The URL request used to establish the WebSocket connection.
    private let urlRequest: URLRequest

    /// The interval at which to send ping frames. If set to 0, auto ping frames will be disabled.
    private let autoPingInterval: TimeInterval

    /// Whether to require network availability before (re)connecting.
    private let requireNetworkAvailable: Bool

    /// The WebSocket engine to use. Default is `.tcpTransport`.
    private let engine: WebSocketEngine

    /// The strategy to use for reconnecting.
    private let reconnectStrategy: ReconnectStrategy

    /// The WebSocket instance used for the connection.
    private let webSocket: WebSocket

    /// Network path monitor to check network availability.
    private let networkPath = NetworkPath()

    /// The current reconnect count.
    private var reconnectCount: UInt = 0

    /// Auto ping timer.
    private var autoPingTimer: AsyncTimer?

    /// Reconnect timer.
    private var reconnectTimer: AsyncTimer?

    /// The state of the WebSocket connection.
    @WebSocketClientActor
    private var state: WebSocketState = .closed

    /// Initializes a new `WebSocketClient` instance.
    /// - Parameters:
    ///   - urlRequest: The URL request to use for the WebSocket connection.
    ///   - autoPingInterval: The interval at which to send ping frames, If set to 0, auto ping frames will be disabled.
    ///   - requireNetworkAvailable: Whether to require network availability before (re)connecting.
    ///   - engine: The WebSocket engine to use, default is `.tcpTransport`.
    ///   - reconnectStrategy: The strategy to use for reconnecting.
    public required init(urlRequest: URLRequest,
                         autoPingInterval: TimeInterval = 0,
                         requireNetworkAvailable: Bool = true,
                         engine: WebSocketEngine = .tcpTransport,
                         reconnectStrategy: ReconnectStrategy = WebSocketClient.defaultReconnectStrategy)
    {
        self.urlRequest = urlRequest
        self.autoPingInterval = autoPingInterval
        self.requireNetworkAvailable = requireNetworkAvailable
        self.engine = engine
        self.reconnectStrategy = reconnectStrategy
        self.webSocket = WebSocket(request: urlRequest, useCustomEngine: {
            switch engine {
            case .tcpTransport: return true
            case .urlSession: return false
            }
        }())
        if requireNetworkAvailable {
            // start monitoring network path if requireNetworkAvailable is true
            Task { await self.startWatchingNetworkPath() }
        }
    }

    /// Initializes a new `WebSocketClient` instance with a URL and additional parameters.
    /// - Parameters:
    ///   - url: The URL to use for the WebSocket connection.
    ///   - cachePolicy: The cache policy to use for the URL request.
    ///   - connectionTimeout: The timeout interval for the connection.
    ///   - connectionHeader: The HTTP headers to include in the URL request.
    ///   - autoPingInterval: The interval at which to send ping frames, If set to 0, ping frames will not be sent.
    ///   - requireNetworkAvailable: Whether to require network availability before (re)connecting.
    ///   - engine: The WebSocket engine to use, default is `.tcpTransport`.
    ///   - reconnectStrategy: The strategy to use for reconnecting.
    public convenience init(url: URL,
                            cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                            connectionTimeout: TimeInterval = 5,
                            connectionHeader: [String: String],
                            autoPingInterval: TimeInterval = 0,
                            requireNetworkAvailable: Bool = true,
                            engine: WebSocketEngine = .tcpTransport,
                            reconnectStrategy: ReconnectStrategy = WebSocketClient.defaultReconnectStrategy)
    {
        self.init(urlRequest: .init(url: url,
                                    cachePolicy: cachePolicy,
                                    timeoutInterval: connectionTimeout,
                                    httpHeaders: connectionHeader),
                  autoPingInterval: autoPingInterval,
                  requireNetworkAvailable: requireNetworkAvailable,
                  engine: engine,
                  reconnectStrategy: reconnectStrategy)
    }
}

// MARK: - Public API

@WebSocketClientActor
public extension WebSocketClient {
    /// Connects to the WebSocket server.
    func connect() async {
        if case .connected = state {
            debugPrint("websocket connect ignored: connection is already connected")
            return
        }
        if case .connecting = state {
            debugPrint("websocket connect ignored: connection is already connecting")
            return
        }
        if requireNetworkAvailable, await !networkPath.isSatisfied {
            debugPrint("websocket connect ignored: network is not available")
            return
        }
        state = .connecting
        webSocket.delegate = self
        webSocket.connect()
    }

    /// Disconnects from the WebSocket server.
    /// - Parameter closeCode: The close code to use for the disconnection.
    func disconnect(closeCode: WebSocketCloseCode = .normal) async {
        webSocket.disconnect(closeCode: closeCode.rawValue)
        await disableAutoPing()
    }

    /// Forcefully disconnects from the WebSocket server.
    func forceDisconnect() async {
        webSocket.forceDisconnect()
        await disableAutoPing()
        await destroyReconnectTimer(resetCount: true)
    }

    /// Sends a WebSocket frame.
    /// - Parameter frame: The frame to send.
    func send(_ frame: WebSocketFrameOpCode) async {
        guard case .connected = state else {
            debugPrint("websocket send ignored: connection is not connected")
            return
        }
        await withCheckedContinuation { cont in
            switch frame {
            case .pong(let data): webSocket.write(pong: data) { cont.resume() }
            case .ping(let data): webSocket.write(ping: data) { cont.resume() }
            case .text(let string): webSocket.write(string: string) { cont.resume() }
            case .binary(let data): webSocket.write(data: data) { cont.resume() }
            }
        }
    }

    /// Sends a text frame.
    /// - Parameter string: The string to send.
    /// - Parameter data: The data to include in the frame.
    func ping(data: Data = Data()) async {
        await send(.ping(data))
    }

    /// Sends a binary frame.
    /// - Parameter data: The data to send.
    func pong(data: Data = Data()) async {
        await send(.pong(data))
    }
}

// MARK: - Reconnect

public extension WebSocketClient {
    private func tryReconnectAfterNetworkRecovery(path: NWPath) async {
        guard await networkPath.isSatisfied else { return }
        guard case .failed = await state else { return }
        await reconnect(reason: .networkRecovery(path))
    }

    private func reconnect(reason: ReconnectReason) async {
        debugPrint("try reconnect for reason: \(reason.description)")
        let currentState = await state
        guard case .failed = currentState else {
            debugPrint("skip reconnect for current state is \(currentState.rawValue)")
            return
        }
        let currentNetworkPath = await networkPath.currentPath
        let delay = await reconnectStrategy.reconnectDelay(webSocket: self,
                                                           reconnectReason: reason,
                                                           reconnectCount: reconnectCount,
                                                           networkPath: currentNetworkPath)
        guard delay > 0 else {
            debugPrint("stop reconnect for reconnectStrategy without valid delay")
            return
        }
        if requireNetworkAvailable, await !networkPath.isSatisfied {
            debugPrint("skip reconnect for network is not available")
            // reset reconnect count for network not available, because need reconnect after network recovery as soon as possible
            await destroyReconnectTimer(resetCount: true)
            return
        }
        await scheduleReconnectTimer(interval: delay)
    }

    private func scheduleReconnectTimer(interval: TimeInterval) async {
        debugPrint("schedule reconnect after \(interval) seconds")
        reconnectTimer = AsyncTimer(interval: interval, repeating: false) { [weak self] in
            guard let self else { return }
            await self.connect()
        }
        await reconnectTimer?.start()
        reconnectCount += 1
    }

    private func destroyReconnectTimer(resetCount: Bool = false) async {
        defer {
            if resetCount { reconnectCount = 0 }
        }
        guard let reconnectTimer else { return }
        await reconnectTimer.stop()
        self.reconnectTimer = nil
    }
}

// MARK: - Watch Network

extension WebSocketClient {
    func startWatchingNetworkPath() async {
        if await networkPath.isValid {
            await stopWatchingNetworkPath()
        }
        await networkPath.fire()
        await networkPath.pathOnChange { [weak self] path in
            guard let self else { return }
            guard path.isSatisfied else {
                debugPrint("Network is not available")
                return
            }
            if case .failed = await state {
                debugPrint("Network recovered, try reconnect")
                await tryReconnectAfterNetworkRecovery(path: path)
            } else {
                debugPrint("Network recovered")
            }
        }
    }

    func stopWatchingNetworkPath() async {
        guard await networkPath.isValid else { return }
        await networkPath.invalidate()
    }
}

// MARK: - Ping Pong

private extension WebSocketClient {
    func enableAutoPing() async {
        await disableAutoPing()
        guard autoPingInterval > 0 else { return }
        autoPingTimer = AsyncTimer(interval: autoPingInterval, repeating: true, firesImmediately: true) {
            Task { await self.ping() }
        }
    }

    func disableAutoPing() async {
        guard let autoPingTimer else { return }
        await autoPingTimer.stop()
        self.autoPingTimer = nil
    }
}

// MARK: - WebSocket Events

@WebSocketClientActor
extension WebSocketClient {
    func receive(event: WebSocketClient.Event) async {}
}

// MARK: - WebSocketDelegate

extension WebSocketClient: WebSocketDelegate {
    public func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        let clientEvent = WebSocketClient.Event(event: event)
        Task { @WebSocketClientActor in
            await self.receive(event: clientEvent)
            let shouldReconnect = await self.reconnectStrategy.shouldReconnectWhenReceivingEvent(webSocket: self, event: clientEvent)
            if shouldReconnect {
                await self.reconnect(reason: .exceptionEvent(clientEvent))
            }
        }
        switch event {
        case .connected(let headers):
            Task { @WebSocketClientActor in
                self.state = .connected
                await self.destroyReconnectTimer(resetCount: true)
                await self.enableAutoPing()
            }
        case .disconnected(let reason, let code):
            Task { @WebSocketClientActor in
                self.state = .closed
                await self.destroyReconnectTimer(resetCount: true)
                await self.disableAutoPing()
            }
        case .error(let error):
            Task { @WebSocketClientActor in
                self.state = .failed
            }
        case .viabilityChanged(let viability):
            Task { @WebSocketClientActor in
            }
        case .reconnectSuggested(let suggested):
            Task { @WebSocketClientActor in
                let event = WebSocketClient.Event.reconnectSuggested(suggested)
                if suggested {
                    await self.forceDisconnect()
                    self.state = .failed
                }
            }
        case .cancelled:
            Task { @WebSocketClientActor in
                self.state = .failed
            }
        case .peerClosed:
            Task { @WebSocketClientActor in
            }
        default:
            break
        }
    }
}

public extension WebSocketClient {
    enum ReconnectReason: Sendable, CustomStringConvertible {
        case exceptionEvent(WebSocketClient.Event)
        case networkRecovery(NWPath)

        public var description: String {
            switch self {
            case .exceptionEvent(let event):
                return "websocket exception event occurred of \(event.description)"
            case .networkRecovery(let nWPath):
                return "network recovery for \(nWPath.debugDescription)"
            }
        }
    }
}

@globalActor
public enum WebSocketClientActor {
    public actor TheActor {}
    public static let shared = TheActor()
}
