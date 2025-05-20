//
//  WebSocketFrame.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

public extension WebSocketClient {
    enum FrameOpCode: Sendable {
        case ping(Data = Data())
        case pong(Data = Data())
        case text(String)
        case binary(Data)
    }
}
