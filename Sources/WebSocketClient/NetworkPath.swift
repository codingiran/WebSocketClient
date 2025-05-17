//
//  NetworkPath.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation
import Network

/// A class that monitors network path changes using `NWPathMonitor`.
/// It provides an asynchronous stream of `NWPath` updates.
/// This class is designed to be used in an actor context to ensure thread safety.
public actor NetworkPath {
    private let networkMonitor: NWPathMonitor
    private var networkPath: NWPath
    private var continuation: AsyncStream<NWPath>.Continuation?

    public init(pathMonitor: NWPathMonitor = .init(),
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
   
    private func setNetworkPath(_ path: NWPath) {
        networkPath = path
        continuation?.yield(path)
    }
}

// MARK: - Public API

public extension NetworkPath {
    /// A Boolean value indicating whether the network path is satisfied.
    var isSatisfied: Bool {
        networkPath.isSatisfied
    }

    /// A method that returns an asynchronous stream of network path changes.
    func networkPathChanges() -> AsyncStream<NWPath> {
        return AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.networkPath)
        }
    }

}