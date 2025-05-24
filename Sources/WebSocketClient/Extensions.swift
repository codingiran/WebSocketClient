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
    var isAbnormalClosed: Bool {
        // RFC 6455 about close codes: https://datatracker.ietf.org/doc/html/rfc6455#section-7.4.1
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

// extension URLSessionWebSocketTask {
//    func sendPing() async throws {
//        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
//            self.sendPing { error in
//                if let error {
//                    cont.resume(throwing: error)
//                } else {
//                    cont.resume()
//                }
//            }
//        }
//    }
// }
