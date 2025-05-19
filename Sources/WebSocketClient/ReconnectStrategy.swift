//
//  WebSocketReconnectStrategy.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/19.
//

import Foundation
import Network

// MARK: - Reconnect Strategy

public extension WebSocketClient {
    protocol ReconnectStrategy: Sendable {
        /// Reconnect delay of every reconnect attempt
        /// - Parameters:
        ///  - webSocket: The WebSocketClient instance
        /// - reconnectReason: The reason for the reconnection
        /// - reconnectCount: The number of reconnections
        /// - networkPath: The current network path
        func reconnectDelay(webSocket: WebSocketClient, reconnectReason: ReconnectReason, reconnectCount: UInt, networkPath: NWPath) async -> TimeInterval

        /// Whether to reconnect when the network is recovered
        /// - Parameters:
        /// - webSocket: The WebSocketClient instance
        /// - networkPath: The current network path
        func shouldReconnectWhenNetworkRecovered(webSocket: WebSocketClient, networkPath: NWPath) async -> Bool

        /// Whether to reconnect when receiving specific websocket event
        func shouldReconnectWhenReceivingEvent(webSocket: WebSocketClient, event: WebSocketClient.Event) async -> Bool
    }

    /// Default ReconnectStrategy
    /// - Note: Exponential Backoff with base 2 and scale 0.5
    /// - Note: This strategy will pause when the network is not satisfied.
    static let defaultReconnectStrategy = ExponentialReconnectStrategy(exponentialBackoffBase: 2, exponentialBackoffScale: 0.5)
}

public extension WebSocketClient.ReconnectStrategy {
    func shouldReconnectWhenNetworkRecovered(webSocket: WebSocketClient, networkPath: NWPath) async -> Bool {
        return true
    }

    func shouldReconnectWhenReceivingEvent(webSocket: WebSocketClient, event: WebSocketClient.Event) async -> Bool {
        switch event {
        case .error, .cancelled:
            return true
        case .reconnectSuggested(let suggested):
            return suggested
        default:
            return false
        }
    }
}

// MARK: - Below are some common reconnection strategies for reference, and they can also be implemented according to business needs.

public extension WebSocketClient {
    /// No  reconnection
    struct NoReconnectStrategy: ReconnectStrategy, Sendable {
        public func reconnectDelay(webSocket: WebSocketClient, reconnectReason: WebSocketClient.ReconnectReason, reconnectCount: UInt, networkPath: NWPath) async -> TimeInterval {
            return 0
        }

        public func shouldReconnectWhenNetworkRecovered(webSocket: WebSocketClient, networkPath: NWPath) async -> Bool {
            return true
        }
    }

    /// Exponential Backoff
    struct ExponentialReconnectStrategy: WebSocketClient.ReconnectStrategy, Sendable {
        private let exponentialBackoffBase: UInt
        private let exponentialBackoffScale: Double
        private let maxRetryCount: UInt

        public init(exponentialBackoffBase: UInt, exponentialBackoffScale: Double, maxRetryCount: UInt = .max) {
            self.exponentialBackoffBase = exponentialBackoffBase
            self.exponentialBackoffScale = exponentialBackoffScale
            self.maxRetryCount = maxRetryCount
        }

        public init(exponentialBackoffBase: UInt, exponentialBackoffScale: Double) {
            self.exponentialBackoffBase = exponentialBackoffBase
            self.exponentialBackoffScale = exponentialBackoffScale
            self.maxRetryCount = .max
        }

        public func reconnectDelay(webSocket: WebSocketClient, reconnectReason: WebSocketClient.ReconnectReason, reconnectCount: UInt, networkPath: NWPath) async -> TimeInterval {
            guard networkPath.isSatisfied else { return 0 }
            guard reconnectCount < maxRetryCount else { return 0 }
            return pow(Double(exponentialBackoffBase), Double(reconnectCount)) * exponentialBackoffScale
        }
    }

    /// Fixed Delay
    struct FixedDelayReconnectStrategy: WebSocketClient.ReconnectStrategy, Sendable {
        private let fixedDelay: TimeInterval
        private let maxRetryCount: UInt

        public init(fixedDelay: TimeInterval, maxRetryCount: UInt = .max) {
            self.fixedDelay = fixedDelay
            self.maxRetryCount = maxRetryCount
        }

        public func reconnectDelay(webSocket: WebSocketClient, reconnectReason: WebSocketClient.ReconnectReason, reconnectCount: UInt, networkPath: NWPath) async -> TimeInterval {
            guard networkPath.isSatisfied else { return 0 }
            guard reconnectCount < maxRetryCount else { return 0 }
            return fixedDelay
        }
    }

    /// Linear Delay
    struct LinearDelayReconnectStrategy: WebSocketClient.ReconnectStrategy, Sendable {
        private let linearDelay: TimeInterval
        private let maxRetryCount: UInt

        public init(linearDelay: TimeInterval, maxRetryCount: UInt = .max) {
            self.linearDelay = linearDelay
            self.maxRetryCount = maxRetryCount
        }

        public func reconnectDelay(webSocket: WebSocketClient, reconnectReason: WebSocketClient.ReconnectReason, reconnectCount: UInt, networkPath: NWPath) async -> TimeInterval {
            guard networkPath.isSatisfied else { return 0 }
            guard reconnectCount < maxRetryCount else { return 0 }
            return linearDelay * Double(reconnectCount)
        }
    }
}
