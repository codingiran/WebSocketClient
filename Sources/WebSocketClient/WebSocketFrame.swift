//
//  WebSocketFrame.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

/*
 public enum FrameOpCode: UInt8 {
     case continueFrame = 0x0
     case textFrame = 0x1
     case binaryFrame = 0x2
     // 3-7 are reserved.
     case connectionClose = 0x8
     case ping = 0x9
     case pong = 0xA
     // B-F reserved.
     case unknown = 100
 }
 */
public enum WebSocketFrameOpCode: Sendable {
    case ping(Data = Data())
    case pong(Data = Data())
    case text(String)
    case binary(Data)
}

/*
 public enum CloseCode: UInt16 {
     case normal                 = 1000
     case goingAway              = 1001
     case protocolError          = 1002
     case protocolUnhandledType  = 1003
     // 1004 reserved.
     case noStatusReceived       = 1005
     //1006 reserved.
     case encoding               = 1007
     case policyViolated         = 1008
     case messageTooBig          = 1009
 }
 */
public enum WebSocketCloseCode: UInt16, Sendable {
    case normal = 1000
    case goingAway = 1001
    case protocolError = 1002
    case protocolUnhandledType = 1003
    // 1004 reserved.
    case noStatusReceived = 1005
    // 1006 reserved.
    case encoding = 1007
    case policyViolated = 1008
    case messageTooBig = 1009
}
