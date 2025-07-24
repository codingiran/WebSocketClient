//
//  WebSocketClient.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/05/16.
//

import AsyncTimer
import Foundation
import NetworkPathMonitor

// Enforce minimum Swift version for all platforms and build systems.
#if swift(<5.10)
    #error("WebSocketClient doesn't support Swift versions below 5.10")
#endif

public enum WebSocketClientInfo: Sendable {
    /// Current WebSocketClient version.
    public static let version = "0.0.6"
}

public final actor WebSocketClient: Sendable {
    /// The URL request used to establish the WebSocket connection.
    public let urlRequest: URLRequest

    /// The interval at which to send ping frames. If set to 0, auto ping will be disabled. Default is 0 seconds.
    public let autoPingInterval: TimeInterval

    /// The WebSocket backend to use.
    public let webSocketBackend: WebSocketClientBackend

    /// The strategy to use for reconnecting.
    public let reconnectStrategy: ReconnectStrategy

    /// The debounce interval for network path monitoring. 0 means no debounce. Default is 0 seconds.
    public let networkMonitorDebounceInterval: TimeInterval

    /// Network path monitor to check network availability.
    private let networkMonitor: NetworkPathMonitor

    /// The current reconnect count.
    public private(set) var reconnectCount: UInt = 0

    /// Auto ping timer.
    private var autoPingTimer: AsyncTimer?

    /// Reconnect timer.
    private var reconnectTimer: AsyncTimer?

    /// The status of the WebSocket connection.
    public private(set) var status: WebSocketClientStatus = .closed(state: .normal)

    /// The delegate of the WebSocket client.
    private weak var delegate: WebSocketClient.Delegate?

    /// Initializes a new `WebSocketClient` instance.
    /// - Parameters:
    ///   - urlRequest: The URL request to use for the WebSocket connection.
    ///   - autoPingInterval: The interval at which to send ping frames, If set to 0, auto ping will be disabled, Default is 0 seconds.
    ///   - webSocketBackend: The WebSocket backend to use.
    ///   - reconnectStrategy: The strategy to use for reconnecting.
    ///   - networkMonitorDebounceInterval: The debounce interval for network path monitoring. 0 means no debounce. Default is 0 seconds.
    ///   - delegate: The delegate of the WebSocket client.
    public init(urlRequest: URLRequest,
                autoPingInterval: TimeInterval = 0,
                webSocketBackend: WebSocketClientBackend,
                reconnectStrategy: ReconnectStrategy = WebSocketClient.defaultReconnectStrategy,
                networkMonitorDebounceInterval: TimeInterval = 0,
                delegate: WebSocketClient.Delegate? = nil)
    {
        precondition(autoPingInterval >= 0, "autoPingInterval must be greater than or equal to 0")
        precondition(networkMonitorDebounceInterval >= 0, "networkMonitorDebounceInterval must be greater than or equal to 0")
        self.urlRequest = urlRequest
        self.autoPingInterval = autoPingInterval
        self.webSocketBackend = webSocketBackend
        self.reconnectStrategy = reconnectStrategy
        self.networkMonitorDebounceInterval = networkMonitorDebounceInterval
        self.delegate = delegate
        networkMonitor = NetworkPathMonitor(debounceInterval: .seconds(networkMonitorDebounceInterval))
        Task {
            // start network path monitoring
            await self.startWatchingNetworkPath()
            // wait for events
            await self.waitForWebSocketEvent()
        }
    }

    /// Initializes a new `WebSocketClient` instance with a URL and additional parameters.
    /// - Parameters:
    ///   - url: The URL to use for the WebSocket connection.
    ///   - cachePolicy: The cache policy to use for the URL request.
    ///   - connectTimeout: The timeout interval for the connection.
    ///   - httpHeaders: The HTTP headers to include in the URL request.
    ///   - autoPingInterval: The interval at which to send ping frames, If set to 0, ping frames will not be sent.
    ///   - webSocketBackend: The WebSocket backend to use.
    ///   - reconnectStrategy: The strategy to use for reconnecting.
    ///   - networkMonitorDebounceInterval: The debounce interval for network path monitoring. 0 means no debounce. Default is 0 seconds.
    ///   - delegate: The delegate of the WebSocket client.
    public init(url: URL,
                cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                connectTimeout: TimeInterval = 5,
                httpHeaders: [String: String],
                autoPingInterval: TimeInterval = 0,
                webSocketBackend: WebSocketClientBackend,
                reconnectStrategy: ReconnectStrategy = WebSocketClient.defaultReconnectStrategy,
                networkMonitorDebounceInterval: TimeInterval = 0,
                delegate: WebSocketClient.Delegate? = nil)
    {
        precondition(connectTimeout > 0, "connectTimeout must be greater than 0")
        self.init(urlRequest: .init(url: url,
                                    cachePolicy: cachePolicy,
                                    timeoutInterval: connectTimeout,
                                    httpHeaders: httpHeaders),
                  autoPingInterval: autoPingInterval,
                  webSocketBackend: webSocketBackend,
                  reconnectStrategy: reconnectStrategy,
                  networkMonitorDebounceInterval: networkMonitorDebounceInterval,
                  delegate: delegate)
    }

    /// Updates the status of the WebSocket connection.
    /// - Parameter status: The new status of the WebSocket connection.
    private func updateStatus(_ status: WebSocketClientStatus) async {
        guard status != self.status else { return }
        self.status = status
        await webSocketDidChangeStatus(status)
    }
}

// MARK: - Public API

public extension WebSocketClient {
    /// Sets the delegate of the WebSocket client.
    /// - Parameter delegate: The new delegate of the WebSocket client.
    func setDelegate(_ delegate: WebSocketClient.Delegate) {
        self.delegate = delegate
    }

    /// Connects to the WebSocket server.
    /// - Returns: A boolean indicating whether the connection was successful.
    /// - Note: The return not means websocket connected successfully, but the connection process is started.
    @discardableResult
    func connect() async -> Bool {
        guard case .closed = status else {
            warningLog("websocket connect ignored for current status is \(status.description)")
            return false
        }
        debugLog("websocket start connecting \(urlRequest.url?.absoluteString ?? "")")
        await updateStatus(.connecting)
        await webSocketBackend.connect(request: urlRequest)
        return true
    }

    /// Disconnects from the WebSocket server.
    /// - Parameter closeCode: The close code to use for the disconnection.
    /// - Parameter reason: The reason for the disconnection.
    func disconnect(closeCode: WebSocketClientCloseCode = .normalClosure, reason: String? = nil) async {
        await webSocketBackend.disconnect(closeCode: closeCode, reason: reason)
        await disableAutoPing()
        await destroyReconnectTimer(resetCount: true)
    }

    /// Sends a WebSocket frame.
    /// - Parameter frame: The frame to send.
    func send(_ frame: WebSocketClientFrame) async throws {
        guard case .connected = status else {
            warningLog("websocket send \(frame.description) frame ignored, connection is not connected")
            return
        }
        try await webSocketBackend.write(frame: frame)
    }

    /// Sends a text frame.
    /// - Parameter string: The string to send.
    /// - Parameter data: The data to include in the frame.
    func ping() async throws {
        try await send(.ping)
    }
}

// MARK: - Status On Change

private extension WebSocketClient {
    func webSocketDidChangeStatus(_ status: WebSocketClientStatus) async {
        switch status {
        case .connected:
            // start auto ping
            await enableAutoPing()
            // destroy reconnect timer after connected
            await destroyReconnectTimer(resetCount: true)
        case let .closed(state):
            // stop auto ping
            await disableAutoPing()
            // destroy reconnect timer after closed
            // if normal closure, no need to reconnect, if abnormal closure, reconnect
            await destroyReconnectTimer(resetCount: state.isNormal)
        default:
            break
        }
        delegate?.webSocketClient(self, didUpdate: status)
    }
}

// MARK: - Reconnect

private extension WebSocketClient {
    func tryReconnectAfterNetworkRecovery(path: NetworkPath) async {
        guard case let .closed(state) = status,
              state.isAbnormal
        else {
            // only reconnect when abnormal closure
            verboseLog("skip reconnect for current status is \(status.description)")
            return
        }
        // ask reconnect strategy if reconnect is immediate
        let shouldReconnectImmediately = await reconnectStrategy.shouldReconnectImmediatelyWhenNetworkRecovered(webSocket: self, networkPath: path)
        debugLog("network recovered, try reconnect immediately: \(shouldReconnectImmediately)")
        await reconnect(reason: .networkRecovery(path), shouldImmediately: shouldReconnectImmediately)
    }

    func reconnect(reason: ReconnectReason, shouldImmediately: Bool = false) async {
        if case .connecting = status {
            // skip reconnect for duplicate connecting
            debugLog("skip reconnect for current status is \(status.description)")
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
            if case .connected = status {
                // disconnect before reconnect
                debugLog("current status is \(status.description), should disconnect before reconnect")
                await disconnect(closeCode: .normalClosure)
            }
            await scheduleReconnectTimer(interval: shouldImmediately ? 0 : interval, reason: reason)
        }
    }

    func scheduleReconnectTimer(interval: TimeInterval, reason: ReconnectReason) async {
        debugLog("schedule \(reconnectCount)th reconnect attempt after \(interval) seconds, reason: \(reason.debugDescription) ")
        await destroyReconnectTimer(resetCount: false)
        delegate?.webSocketClientWillTryReconnect(self, forReason: reason, afterDelay: interval)
        guard interval > 0 else {
            await excuteReconnect(for: reason)
            return
        }
        reconnectTimer = AsyncTimer(interval: interval, repeating: false) { [weak self] in
            guard let self else { return }
            await excuteReconnect(for: reason)
        }
        await reconnectTimer?.start()
    }

    func excuteReconnect(for reason: ReconnectReason) async {
        guard await connect() else { return }
        reconnectCount += 1
        delegate?.webSocketClientDidTryReconnect(self, forReason: reason, withAttemptCount: reconnectCount)
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
            guard !path.isFirstUpdate else {
                await verboseLog("network is satisfied, path is \(path.debugDescription), ignore for first update")
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
            async let _ = try? await ping()
            await delegate?.webSocketClientDidSendAutoPing(self)
        }
        await autoPingTimer?.start()
    }

    func disableAutoPing() async {
        guard let autoPingTimer else { return }
        await autoPingTimer.stop()
        self.autoPingTimer = nil
    }
}

// MARK: - WebSocket Events

extension WebSocketClient {
    func waitForWebSocketEvent() async {
        for await event in webSocketBackend.eventStream {
            await didReceive(event: event)
        }
    }

    func didReceive(event: WebSocketClientEvent) async {
        if case .connected = event {
            await updateStatus(.connected)
        } else if case let .disconnected(_, code) = event {
            await updateStatus(.closed(state: code.isAbnormalClosed ? .abnormal : .normal))
        } else if case .error = event {
            await updateStatus(.closed(state: .abnormal))
        }
        delegate?.webSocketClient(self, didReceive: event)
        if await reconnectStrategy.shouldReconnectWhenReceivingEvent(webSocket: self, event: event) {
            await reconnect(reason: .suggestedEvent(event))
        } else {
            await destroyReconnectTimer(resetCount: true)
        }
    }
}

// MARK: - WebSocket Log

extension WebSocketClient {
    func log(_ log: WebSocketClientLog) {
        delegate?.webSocketClient(self, didOutput: log)
    }

    func verboseLog(_ message: String) {
        log(.init(level: .verbose, message: message))
    }

    func debugLog(_ message: String) {
        log(.init(level: .debug, message: message))
    }

    func infoLog(_ message: String) {
        log(.init(level: .info, message: message))
    }

    func warningLog(_ message: String) {
        log(.init(level: .warning, message: message))
    }

    func errorLog(_ message: String) {
        log(.init(level: .error, message: message))
    }
}
