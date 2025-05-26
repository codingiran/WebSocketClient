//
//  Extensions.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/26.
//

import Foundation
import Starscream
import WebSocketCore

extension Starscream.CloseCode {
    init(closeCode: WebSocketClientCloseCode) {
        self = .init(rawValue: UInt16(closeCode.rawValue)) ?? .normal
    }
}

extension WebSocketClientCloseCode {
    init(closeCode: Starscream.CloseCode) {
        self = .init(rawValue: Int(closeCode.rawValue)) ?? .invalid
    }

    init(code: UInt16) {
        self = .init(rawValue: Int(code)) ?? .invalid
    }
}
