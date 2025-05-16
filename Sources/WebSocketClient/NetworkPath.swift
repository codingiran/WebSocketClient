//
//  NetworkPath.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation
import Network

public actor NetworkPath {
    let networkMonitor: NWPathMonitor
    var networkPath: NWPath
    private var continuation: AsyncStream<NWPath>.Continuation?

    init(pathMonitor: NWPathMonitor = .init(),
         queue: DispatchQueue = .init(label: "com.websocketClient.pathMonitor.\(UUID())"))
    {
        networkMonitor = pathMonitor
        networkPath = networkMonitor.currentPath
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            Task { await self.setNetworkPath(path) }
        }
        networkMonitor.start(queue: queue)
    }

    public var isSatisfied: Bool {
        networkPath.isSatisfied
    }

    public func networkPathChanges() -> AsyncStream<NWPath> {
        return AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.networkPath)
        }
    }

    private func setNetworkPath(_ path: NWPath) {
        networkPath = path
        continuation?.yield(path)
    }
}
