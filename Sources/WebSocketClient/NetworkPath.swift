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
    public typealias PathUpdateHandler = @Sendable (Network.NWPath) async -> Void

    private let monitorQueue: DispatchQueue

    private var networkPathUpdater: PathUpdateHandler?

    private let networkMonitor: NWPathMonitor = .init()

    /// A Boolean value that indicates whether the network path is valid.
    public var isValid: Bool = false

    public private(set) var currentPath: NWPath

    public init(queue: DispatchQueue = .init(label: "com.websocketClient.pathMonitor.\(UUID())")) {
        monitorQueue = queue
        currentPath = networkMonitor.currentPath
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            Task { await self.updateNetworkPath(path) }
        }
    }

    private func updateNetworkPath(_ path: NWPath) async {
        currentPath = path
        await networkPathUpdater?(path)
    }
}

// MARK: - Public API

public extension NetworkPath {
    /// Starts monitoring the network path.
    func fire() {
        networkMonitor.start(queue: monitorQueue)
        isValid = true
    }

    /// Stops monitoring the network path.
    func invalidate() {
        networkMonitor.cancel()
        isValid = false
    }

    /// A Boolean value indicating whether the network path is satisfied.
    var isSatisfied: Bool {
        currentPath.isSatisfied
    }

    func pathOnChange(_ handler: @escaping PathUpdateHandler) {
        networkPathUpdater = handler
    }
}
