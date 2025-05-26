//
//  WebSocketCloseCode.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/26.
//

import Foundation

/// The close code of the WebSocket connection.
public enum WebSocketClientCloseCode: Int, Sendable, Equatable {
    // RFC 6455 about close codes: https://datatracker.ietf.org/doc/html/rfc6455#section-7.4.1
    case invalid = 0
    case normalClosure = 1000
    case goingAway = 1001
    case protocolError = 1002
    case unsupportedData = 1003
    case noStatusReceived = 1005
    case abnormalClosure = 1006
    case invalidFramePayloadData = 1007
    case policyViolation = 1008
    case messageTooBig = 1009
    case mandatoryExtensionMissing = 1010
    case internalServerError = 1011
    case tlsHandshakeFailure = 1015
}

public extension WebSocketClientCloseCode {
    var isAbnormalClosed: Bool {
        switch self {
        case
            // 1000, A code that indicates normal connection closure.
            .normalClosure,
            // 1001, A code that indicates an endpoint is going away.
            .goingAway,
            // 1010, A code that indicates the client terminated the connection because the server didn’t negotiate a required extension.
            .mandatoryExtensionMissing:
            return false

        case
            // 0, A code that indicates the connection is still open.
            .invalid,
            // 1002, A code that indicates an endpoint terminated the connection due to a protocol error.
            .protocolError,
            // 1003, A code that indicates an endpoint terminated the connection after receiving a type of data it can’t accept.
            .unsupportedData,
            // 1005, A reserved code that indicates an endpoint expected a status code and didn’t receive one.
            .noStatusReceived,
            // 1006, A reserved code that indicates the connection closed without a close control frame.
            .abnormalClosure,
            // 1007, A code that indicates the server terminated the connection because it received data inconsistent with the message’s type.
            .invalidFramePayloadData,
            // 1008, A code that indicates an endpoint terminated the connection because it received a message that violates its policy.
            .policyViolation,
            // 1009, A code that indicates an endpoint is terminating the connection because it received a message too big for it to process.
            .messageTooBig,
            // 1011, A code that indicates the server terminated the connection because it encountered an unexpected condition.
            .internalServerError,
            // 1015, A reserved code that indicates the connection closed due to the failure to perform a TLS handshake.
            .tlsHandshakeFailure:
            return true

        @unknown default:
            return false
        }
    }
}
