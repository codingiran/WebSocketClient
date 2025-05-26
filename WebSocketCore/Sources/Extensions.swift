//
//  Extensions.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

// MARK: - Extensions

public extension URLRequest {
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
