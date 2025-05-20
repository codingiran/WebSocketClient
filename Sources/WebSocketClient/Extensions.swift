//
//  Extensions.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation
import Network

// MARK: - Extensions

extension URLRequest {
    init(url: URL,
         cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
         timeoutInterval: TimeInterval = 60.0,
         httpHeaders: [String: String])
    {
        self.init(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
        for (key, value) in httpHeaders {
            setValue(value, forHTTPHeaderField: key)
        }
    }
}

public extension Network.NWPath {
    var isSatisfied: Bool { status == .satisfied }
}

extension URLSessionWebSocketTask.CloseCode {
    var isReconnectSuggested: Bool {
        // RFC 6455 about close codes: https://datatracker.ietf.org/doc/html/rfc6455#section-7.4.1
        switch self {
        case
            // A code that indicates an endpoint is going away.
            .goingAway,
            // A reserved code that indicates an endpoint expected a status code and didn’t receive one.
            .noStatusReceived,
            // A reserved code that indicates the connection closed without a close control frame.
            .abnormalClosure,
            // A code that indicates the server terminated the connection because it encountered an unexpected condition.
            .internalServerError:
            return true

        case
            // A code that indicates the connection is still open.
            .invalid,
            // A code that indicates normal connection closure.
            .normalClosure,
            // A code that indicates an endpoint terminated the connection due to a protocol error.
            .protocolError,
            // A code that indicates an endpoint terminated the connection after receiving a type of data it can’t accept.
            .unsupportedData,
            // A code that indicates the server terminated the connection because it received data inconsistent with the message’s type.
            .invalidFramePayloadData,
            // A code that indicates an endpoint terminated the connection because it received a message that violates its policy.
            .policyViolation,
            // A code that indicates an endpoint is terminating the connection because it received a message too big for it to process.
            .messageTooBig,
            // A code that indicates the client terminated the connection because the server didn’t negotiate a required extension.
            .mandatoryExtensionMissing,
            // A reserved code that indicates the connection closed due to the failure to perform a TLS handshake.
            .tlsHandshakeFailure:
            return false

        @unknown default:
            return false
        }
    }
}
