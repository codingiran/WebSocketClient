//
//  WebSocketState.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

public enum WebSocketState: Sendable {
    case connecting
    case connected
    case closed
    case failed
}
