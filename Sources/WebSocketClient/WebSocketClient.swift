//
//  WebSocketClient.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/05/16.
//

import AsyncTimer
import Foundation
import Network
import NetworkPathMonitor
@preconcurrency import Starscream

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.9)
    #error("WebSocketClient doesn't support Swift versions below 5.9")
#endif

public enum WebSocketClientInfo: Sendable {
    /// Current WebSocketClient version.
    public static let version = "0.0.1"
}

public actor WebSocketClient: Sendable {
    /// The URL request used to establish the WebSocket connection.
    public let urlRequest: URLRequest

    /// The interval at which to send ping frames. If set to 0, auto ping will be disabled. Default is 0 seconds.
    public let autoPingInterval: TimeInterval

    /// The WebSocket engine to use. Default is `.tcpTransport`.
    public let engine: WebSocketClient.Engine

    /// The strategy to use for reconnecting.
    public let reconnectStrategy: ReconnectStrategy

    /// The debounce interval for network path monitoring. 0 means no debounce. Default is 0 seconds.
    public let networkMonitorDebounceInterval: TimeInterval

    /// The WebSocket instance used for the connection.
    private let webSocket: WebSocket

    /// Network path monitor to check network availability.
    private let networkMonitor: NetworkPathMonitor

    /// The current reconnect count.
    public private(set) var reconnectCount: UInt = 0

    /// Auto ping timer.
    private var autoPingTimer: AsyncTimer?

    /// Reconnect timer.
    private var reconnectTimer: AsyncTimer?

    /// The state of the WebSocket connection.
    public private(set) var state: WebSocketClient.State = .closed(normalClosure: true) {
        didSet {
            guard state != oldValue else { return }
            Task { await self.webSocketDidChangeState(state) }
        }
    }

    /// The delegate of the WebSocket client.
    public weak var delegate: WebSocketClient.Delegate?

    /// Initializes a new `WebSocketClient` instance.
    /// - Parameters:
    ///   - urlRequest: The URL request to use for the WebSocket connection.
    ///   - autoPingInterval: The interval at which to send ping frames, If set to 0, auto ping will be disabled, Default is 0 seconds.
    ///   - engine: The WebSocket engine to use, default is `.tcpTransport`.
    ///   - reconnectStrategy: The strategy to use for reconnecting.
    ///   - networkMonitorDebounceInterval: The debounce interval for network path monitoring. 0 means no debounce. Default is 0 seconds.
    public init(urlRequest: URLRequest,
                autoPingInterval: TimeInterval = 0,
                engine: WebSocketClient.Engine = .tcpTransport,
                reconnectStrategy: ReconnectStrategy = WebSocketClient.defaultReconnectStrategy,
                networkMonitorDebounceInterval: TimeInterval = 0)
    {
        self.urlRequest = urlRequest
        self.autoPingInterval = autoPingInterval
        self.engine = engine
        self.reconnectStrategy = reconnectStrategy
        self.networkMonitorDebounceInterval = networkMonitorDebounceInterval
        // monitor network path
        precondition(networkMonitorDebounceInterval >= 0, "networkMonitorDebounceInterval must be greater than or equal to 0")
        networkMonitor = NetworkPathMonitor(debounceInterval: networkMonitorDebounceInterval)
        webSocket = WebSocket(request: urlRequest, useCustomEngine: engine.useCustomEngine)
        webSocket.delegate = self
        Task { await self.startWatchingNetworkPath() }
    }

    /// Initializes a new `WebSocketClient` instance with a URL and additional parameters.
    /// - Parameters:
    ///   - url: The URL to use for the WebSocket connection.
    ///   - cachePolicy: The cache policy to use for the URL request.
    ///   - connectTimeout: The timeout interval for the connection.
    ///   - connectionHeader: The HTTP headers to include in the URL request.
    ///   - autoPingInterval: The interval at which to send ping frames, If set to 0, ping frames will not be sent.
    ///   - engine: The WebSocket engine to use, default is `.tcpTransport`.
    ///   - reconnectStrategy: The strategy to use for reconnecting.
    ///   - networkMonitorDebounceInterval: The debounce interval for network path monitoring. 0 means no debounce. Default is 0 seconds.
    public init(url: URL,
                cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                connectTimeout: TimeInterval = 5,
                connectionHeader: [String: String],
                autoPingInterval: TimeInterval = 0,
                engine: WebSocketClient.Engine = .tcpTransport,
                reconnectStrategy: ReconnectStrategy = WebSocketClient.defaultReconnectStrategy,
                networkMonitorDebounceInterval: TimeInterval = 0)
    {
        self.init(urlRequest: .init(url: url,
                                    cachePolicy: cachePolicy,
                                    timeoutInterval: connectTimeout,
                                    httpHeaders: connectionHeader),
                  autoPingInterval: autoPingInterval,
                  engine: engine,
                  reconnectStrategy: reconnectStrategy,
                  networkMonitorDebounceInterval: networkMonitorDebounceInterval)
    }
}

// MARK: - Public API

public extension WebSocketClient {
    /// Connects to the WebSocket server.
    func connect() async {
        guard case .closed = state else {
            warningLog("websocket connect ignored for current state is \(state.description)")
            return
        }
        guard await networkMonitor.isPathSatisfied else {
            warningLog("websocket connect ignored for network is not satisfied")
            state = .closed(normalClosure: false)
            return
        }
        debugLog("websocket start connecting")
        state = .connecting
        webSocket.connect()
    }

    /// Disconnects from the WebSocket server.
    /// - Parameter closeCode: The close code to use for the disconnection.
    func disconnect(closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure) async {
        webSocket.disconnect(closeCode: UInt16(closeCode.rawValue))
        await disableAutoPing()
        await destroyReconnectTimer(resetCount: true)
    }

    /// Forcefully disconnects from the WebSocket server.
    func forceDisconnect() async {
        webSocket.forceDisconnect()
        await disableAutoPing()
        await destroyReconnectTimer(resetCount: true)
    }

    /// Sends a WebSocket frame.
    /// - Parameter frame: The frame to send.
    func send(_ frame: WebSocketClient.FrameOpCode) async {
        guard case .connected = state else {
            warningLog("websocket send \(frame.description) frame ignored, connection is not connected")
            return
        }
        await withCheckedContinuation { cont in
            switch frame {
            case let .pong(data): webSocket.write(pong: data) { cont.resume() }
            case let .ping(data): webSocket.write(ping: data) { cont.resume() }
            case let .text(string): webSocket.write(string: string) { cont.resume() }
            case let .binary(data): webSocket.write(data: data) { cont.resume() }
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

// MARK: - State On Change

private extension WebSocketClient {
    func webSocketDidChangeState(_ state: WebSocketClient.State) async {
        switch state {
        case .connected:
            await enableAutoPing()
        case .closed:
            await disableAutoPing()
        default:
            break
        }
        delegate?.webSocketClient(self, didUpdate: state)
    }
}

// MARK: - Reconnect

private extension WebSocketClient {
    func tryReconnectAfterNetworkRecovery(path: NWPath) async {
        guard case let .closed(normalClosure) = state,
              !normalClosure
        else {
            // only reconnect when abnormal closure
            verboseLog("skip reconnect for current state is \(state.description)")
            return
        }
        // ask reconnect strategy if reconnect is suggested in this network path
        guard await reconnectStrategy.shouldReconnectWhenNetworkRecovered(webSocket: self, networkPath: path) else {
            debugLog("network recovered, but reconnect is not suggested")
            return
        }
        debugLog("network recovered, try reconnect")
        await reconnect(reason: .networkRecovery(path))
    }

    func reconnect(reason: ReconnectReason) async {
        if case .connecting = state {
            // skip reconnect for duplicate connecting
            debugLog("skip reconnect for current state is \(state.description)")
            return
        }
        let method = await reconnectStrategy.reconnectMethod(webSocket: self,
                                                             reconnectReason: reason,
                                                             reconnectCount: reconnectCount,
                                                             networkPath: await networkMonitor.currentPath)
        switch method {
        case let .none(reason):
            debugLog("skip reconnect for \(reason)")
        case let .delay(interval):
            guard interval > 0 else {
                debugLog("skip reconnect for no valid reconnect delay")
                return
            }
            if case .connected = state {
                // disconnect before reconnect
                debugLog("current state is \(state.description), should disconnect before reconnect")
                await disconnect(closeCode: .normalClosure)
            }
            await scheduleReconnectTimer(interval: interval, reason: reason)
        }
    }

    func scheduleReconnectTimer(interval: TimeInterval, reason: ReconnectReason) async {
        debugLog("schedule \(reconnectCount)th reconnect attempt after \(interval) seconds, reason: \(reason.description) ")
        await destroyReconnectTimer(resetCount: false)
        reconnectTimer = AsyncTimer(interval: interval, repeating: false) { [weak self] in
            guard let self else { return }
            await connect()
            await increaseAttemptCount()
            await delegate?.webSocketClientDidTryReconnect(self, forReason: reason, withAttemptCount: await reconnectCount)
        }
        delegate?.webSocketClientWillTryReconnect(self, forReason: reason, afterDelay: interval)
        await reconnectTimer?.start()
    }

    func increaseAttemptCount() {
        reconnectCount += 1
    }

    func destroyReconnectTimer(resetCount: Bool = false) async {
        defer { if resetCount { reconnectCount = 0 } }
        guard let reconnectTimer else { return }
        debugLog("destroy reconnect timer")
        await reconnectTimer.stop()
        self.reconnectTimer = nil
    }
}

// MARK: - Watch Network

extension WebSocketClient {
    func startWatchingNetworkPath() async {
        await stopWatchingNetworkPath()
        await networkMonitor.pathOnChange { [weak self] path in
            guard let self else { return }
            await delegate?.webSocketClient(self, didMonitorNetworkPathChange: path)
            guard path.isSatisfied else {
                await debugLog("network is not satisfied, path is \(path.debugDescription)")
                return
            }
            await debugLog("network is satisfied, path is \(path.debugDescription)")
            await tryReconnectAfterNetworkRecovery(path: path)
        }
        await networkMonitor.fire()
    }

    func stopWatchingNetworkPath() async {
        guard await networkMonitor.isActive else { return }
        await networkMonitor.invalidate()
    }
}

// MARK: - Auto Ping

private extension WebSocketClient {
    func enableAutoPing() async {
        await disableAutoPing()
        guard autoPingInterval > 0 else { return }
        autoPingTimer = AsyncTimer(interval: autoPingInterval, repeating: true, firesImmediately: true) { [weak self] in
            guard let self else { return }
            Task {
                await self.delegate?.webSocketClientWillSendAutoPing(self)
                await self.ping()
                await self.delegate?.webSocketClientDidSendAutoPing(self)
            }
        }
    }

    func disableAutoPing() async {
        guard let autoPingTimer else { return }
        await autoPingTimer.stop()
        self.autoPingTimer = nil
    }
}

// MARK: - WebSocket Events

extension WebSocketClient {
    func receive(event: WebSocketClient.Event) async {
        state = event.state
        delegate?.webSocketClient(self, didReceive: event)
        if await reconnectStrategy.shouldReconnectWhenReceivingEvent(webSocket: self, event: event) {
            await reconnect(reason: .suggestedEvent(event))
        } else {
            await destroyReconnectTimer(resetCount: true)
        }
    }
}

// MARK: - WebSocketDelegate

extension WebSocketClient: @preconcurrency WebSocketDelegate {
    public func didReceive(event: Starscream.WebSocketEvent, client _: any Starscream.WebSocketClient) {
        let clientEvent = WebSocketClient.Event(event: event)
        Task { await self.receive(event: clientEvent) }
    }
}
