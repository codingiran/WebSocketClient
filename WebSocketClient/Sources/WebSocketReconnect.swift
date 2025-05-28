//
//  WebSocketReconnect.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/19.
//

import Foundation
import Network

// MARK: - Reconnect Method

public extension WebSocketClient {
    enum ReconnectMethod: Sendable, Equatable {
        case none(_ reason: String)
        case delay(_ interval: TimeInterval)

        public static let noneForUnSatisfiedNetwork = ReconnectMethod.none("Network not satisfied")
        public static let noneForMaxRetryCount = ReconnectMethod.none("Max retry count reached")
    }
}

// MARK: - Reconnect Reason

public extension WebSocketClient {
    enum ReconnectReason: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
        case suggestedEvent(WebSocketClientEvent)
        case networkRecovery(NWPath)

        public var description: String {
            switch self {
            case .suggestedEvent:
                return "suggested reconnect event"
            case .networkRecovery:
                return "network recovery"
            }
        }

        public var debugDescription: String {
            switch self {
            case let .suggestedEvent(event):
                return "suggested reconnect event(\(event.debugDescription))"
            case let .networkRecovery(nWPath):
                return "network recovery(\(nWPath.debugDescription))"
            }
        }
    }
}

// MARK: - Reconnect Strategy

public extension WebSocketClient {
    protocol ReconnectStrategy: Sendable {
        /// Reconnect method of every reconnect attempt
        /// - Parameters:
        ///  - webSocket: The WebSocketClient instance
        ///  - reconnectReason: The reason for the reconnection
        ///  - reconnectCount: The number of reconnections
        ///  - networkPath: The current network path
        func reconnectMethod(webSocket: WebSocketClient, reconnectReason: ReconnectReason, reconnectCount: UInt, networkPath: NWPath) async -> ReconnectMethod

        /// Whether to reconnect when the network is recovered
        /// - Parameters:
        ///  - webSocket: The WebSocketClient instance
        ///  - networkPath: The current network path
        func shouldReconnectWhenNetworkRecovered(webSocket: WebSocketClient, networkPath: NWPath) async -> Bool

        /// Whether to reconnect when receiving specific websocket event
        /// - Parameters:
        ///  - webSocket: The WebSocketClient instance
        ///  - event: The websocket event
        func shouldReconnectWhenReceivingEvent(webSocket: WebSocketClient, event: WebSocketClientEvent) async -> Bool
    }

    /// Default ReconnectStrategy
    /// - Note: Exponential Backoff with base 2 and scale 0.5, max retry count is .max, max retry interval is 10 minutes, and delay jitter is 0.2.
    /// - Note: This strategy will pause when the network is not satisfied.
    static let defaultReconnectStrategy = ExponentialReconnectStrategy()
}

// MARK: - Default Strategy Implementation

public extension WebSocketClient.ReconnectStrategy {
    func shouldReconnectWhenNetworkRecovered(webSocket _: WebSocketClient, networkPath: NWPath) async -> Bool {
        // Default implementation: reconnect after network is recovered
        networkPath.isSatisfied
    }

    func shouldReconnectWhenReceivingEvent(webSocket _: WebSocketClient, event: WebSocketClientEvent) async -> Bool {
        // Default implementation: reconnect when event is abnormal closed
        event.isAbnormalClosed
    }
}

// MARK: - Pre Established Strategy

public extension WebSocketClient {
    /// No reconnection
    struct NoReconnectStrategy: ReconnectStrategy, Sendable {
        public func reconnectMethod(webSocket _: WebSocketClient, reconnectReason _: WebSocketClient.ReconnectReason, reconnectCount _: UInt, networkPath _: NWPath) async -> ReconnectMethod { .none("") }

        public func shouldReconnectWhenNetworkRecovered(webSocket _: WebSocketClient, networkPath _: NWPath) async -> Bool { false }

        public func shouldReconnectWhenReceivingEvent(webSocket _: WebSocketClient, event _: WebSocketClientEvent) async -> Bool { false }
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

        public func reconnectMethod(webSocket _: WebSocketClient, reconnectReason _: WebSocketClient.ReconnectReason, reconnectCount: UInt, networkPath: NWPath) async -> ReconnectMethod {
            guard networkPath.isSatisfied else { return .noneForUnSatisfiedNetwork }
            guard reconnectCount < maxRetryCount else { return .noneForMaxRetryCount }
            let intervel = pow(Double(exponentialBackoffBase), Double(reconnectCount)) * exponentialBackoffScale
            let delay = min(intervel, maxRetryInterval)
            let jitterRange = delay * delayJitter
            let randomJitter = Double.random(in: -jitterRange ... jitterRange)
            return .delay(delay + randomJitter)
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

        public func reconnectMethod(webSocket _: WebSocketClient, reconnectReason _: WebSocketClient.ReconnectReason, reconnectCount: UInt, networkPath: NWPath) async -> ReconnectMethod {
            guard networkPath.isSatisfied else { return .noneForUnSatisfiedNetwork }
            guard reconnectCount < maxRetryCount else { return .noneForMaxRetryCount }
            return .delay(fixedDelay)
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

        public func reconnectMethod(webSocket _: WebSocketClient, reconnectReason _: WebSocketClient.ReconnectReason, reconnectCount: UInt, networkPath: NWPath) async -> ReconnectMethod {
            guard networkPath.isSatisfied else { return .noneForUnSatisfiedNetwork }
            guard reconnectCount < maxRetryCount else { return .noneForMaxRetryCount }
            return .delay(min(linearDelay * Double(reconnectCount), maxRetryInterval))
        }
    }
}
