//
//  Extensions.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/26.
//

import Foundation
import WebSocketClient

extension URLSessionWebSocketTask.CloseCode {
    init(closeCode: WebSocketClientCloseCode) {
        self = .init(rawValue: closeCode.rawValue) ?? .invalid
    }
}

extension WebSocketClientCloseCode {
    init(closeCode: URLSessionWebSocketTask.CloseCode) {
        self = .init(rawValue: closeCode.rawValue) ?? .invalid
    }
}
