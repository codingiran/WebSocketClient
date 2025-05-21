//
//  ReconnectStrategy.swift
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
        /// - Parameters:
        /// - webSocket: The WebSocketClient instance
        /// - event: The websocket event
        func shouldReconnectWhenReceivingEvent(webSocket: WebSocketClient, event: WebSocketClient.Event) async -> Bool
    }

    /// Default ReconnectStrategy
    /// - Note: Exponential Backoff with base 2 and scale 0.5, max retry count is .max, max retry interval is 10 minutes, and delay jitter is 0.2.
    /// - Note: This strategy will pause when the network is not satisfied.
    static let defaultReconnectStrategy = ExponentialReconnectStrategy()
}

// MARK: - Default implementation

public extension WebSocketClient.ReconnectStrategy {
    func shouldReconnectWhenNetworkRecovered(webSocket _: WebSocketClient, networkPath: NWPath) async -> Bool {
        networkPath.isSatisfied
    }

    func shouldReconnectWhenReceivingEvent(webSocket _: WebSocketClient, event: WebSocketClient.Event) async -> Bool {
        event.isReconnectSuggested
    }
}

// MARK: - Pre established strategy

public extension WebSocketClient {
    /// No reconnection
    struct NoReconnectStrategy: ReconnectStrategy, Sendable {
        public func reconnectDelay(webSocket _: WebSocketClient, reconnectReason _: WebSocketClient.ReconnectReason, reconnectCount _: UInt, networkPath _: NWPath) async -> TimeInterval { 0 }

        public func shouldReconnectWhenNetworkRecovered(webSocket _: WebSocketClient, networkPath _: NWPath) async -> Bool { false }

        public func shouldReconnectWhenReceivingEvent(webSocket _: WebSocketClient, event _: WebSocketClient.Event) async -> Bool { false }
    }

    /// Exponential Backoff
    struct ExponentialReconnectStrategy: WebSocketClient.ReconnectStrategy, Sendable {
        private let exponentialBackoffBase: UInt
        private let exponentialBackoffScale: Double
        private let maxRetryCount: UInt
        private let maxRetryInterval: TimeInterval
        private let delayJitter: TimeInterval

        /// Exponential Backoff strategy
        /// - Parameters:
        ///   - exponentialBackoffBase: The base of the exponential backoff. Default is 2.
        ///   - exponentialBackoffScale: The scale of the exponential backoff. Default is 0.5.
        ///   - maxRetryCount: The maximum number of retry attempts. Default is .max.
        ///   - maxRetryInterval: The maximum retry interval. Default is 10 minutes.
        ///   - delayJitter: The jitter range of the delay. Default is 0.2.
        public init(exponentialBackoffBase: UInt = 2,
                    exponentialBackoffScale: Double = 0.5,
                    maxRetryCount: UInt = .max,
                    maxRetryInterval: TimeInterval = 10 * 60,
                    delayJitter: TimeInterval = 0.2)
        {
            self.exponentialBackoffBase = exponentialBackoffBase
            self.exponentialBackoffScale = exponentialBackoffScale
            self.maxRetryCount = maxRetryCount
            self.maxRetryInterval = maxRetryInterval
            self.delayJitter = delayJitter
        }

        public func reconnectDelay(webSocket _: WebSocketClient, reconnectReason _: WebSocketClient.ReconnectReason, reconnectCount: UInt, networkPath: NWPath) async -> TimeInterval {
            guard networkPath.isSatisfied else { return 0 }
            guard reconnectCount < maxRetryCount else { return 0 }
            let intervel = pow(Double(exponentialBackoffBase), Double(reconnectCount)) * exponentialBackoffScale
            let delay = min(intervel, maxRetryInterval)
            let jitterRange = delay * delayJitter
            let randomJitter = Double.random(in: -jitterRange ... jitterRange)
            return delay + randomJitter
        }
    }

    /// Fixed Delay
    struct FixedDelayReconnectStrategy: WebSocketClient.ReconnectStrategy, Sendable {
        private let fixedDelay: TimeInterval
        private let maxRetryCount: UInt

        /// Fixed Delay strategy
        /// - Parameters:
        ///   - fixedDelay: The fixed delay time. Default is 5 seconds.
        ///   - maxRetryCount: The maximum number of retry attempts. Default is .max.
        public init(fixedDelay: TimeInterval, maxRetryCount: UInt = .max) {
            self.fixedDelay = fixedDelay
            self.maxRetryCount = maxRetryCount
        }

        public func reconnectDelay(webSocket _: WebSocketClient, reconnectReason _: WebSocketClient.ReconnectReason, reconnectCount: UInt, networkPath: NWPath) async -> TimeInterval {
            guard networkPath.isSatisfied else { return 0 }
            guard reconnectCount < maxRetryCount else { return 0 }
            return fixedDelay
        }
    }

    /// Linear Delay
    struct LinearDelayReconnectStrategy: WebSocketClient.ReconnectStrategy, Sendable {
        private let linearDelay: TimeInterval
        private let maxRetryCount: UInt
        private let maxRetryInterval: TimeInterval

        /// Linear Delay strategy
        /// - Parameters:
        ///   - linearDelay: The linear delay time. Default is 5 seconds.
        ///   - maxRetryCount: The maximum number of retry attempts. Default is .max.
        ///   - maxRetryInterval: The maximum retry interval. Default is 10 minutes.
        public init(linearDelay: TimeInterval, maxRetryCount: UInt = .max, maxRetryInterval: TimeInterval = 10 * 60) {
            self.linearDelay = linearDelay
            self.maxRetryCount = maxRetryCount
            self.maxRetryInterval = maxRetryInterval
        }

        public func reconnectDelay(webSocket _: WebSocketClient, reconnectReason _: WebSocketClient.ReconnectReason, reconnectCount: UInt, networkPath: NWPath) async -> TimeInterval {
            guard networkPath.isSatisfied else { return 0 }
            guard reconnectCount < maxRetryCount else { return 0 }
            return min(linearDelay * Double(reconnectCount), maxRetryInterval)
        }
    }
}
