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
    /// A type alias for the network path update handler.
    public typealias PathUpdateHandler = @Sendable (Network.NWPath) async -> Void

    /// The queue on which the network path monitor runs.
    private let monitorQueue: DispatchQueue

    /// The network path update handler.
    private var networkPathUpdater: PathUpdateHandler?

    /// The network path monitor.
    private let networkMonitor: NWPathMonitor = .init()

    /// A Boolean value that indicates whether the network path is valid.
    public var isValid: Bool = false

    /// Current network path.
    public private(set) var currentPath: NWPath

    /// Network path status change notification.
    public static let networkStatusDidChangeNotification = Notification.Name("WebSocketClient.NetworkPathStatusDidChange")

    /// Initializes a new instance of `NetworkPath`.
    /// - Parameter queue: The queue on which the network path monitor runs. Default is a serial queue with a unique label.
    public init(queue: DispatchQueue = .init(label: "com.websocketClient.pathMonitor.\(UUID())")) {
        monitorQueue = queue
        currentPath = networkMonitor.currentPath
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            Task { await self.updateNetworkPath(path) }
        }
    }

    /// Updates the current network path and notifies the handler.
    private func updateNetworkPath(_ path: NWPath) async {
        let oldPath = currentPath
        currentPath = path

        // Notify the path update handler
        await networkPathUpdater?(path)

        // Post network status change notification
        NotificationCenter.default.post(
            name: Self.networkStatusDidChangeNotification,
            object: self,
            userInfo: [
                "oldPath": oldPath,
                "newPath": path,
            ]
        )
    }
}

// MARK: - Public API

public extension NetworkPath {
    /// Starts monitoring the network path.
    func fire() {
        guard !isValid else { return }
        networkMonitor.start(queue: monitorQueue)
        isValid = true
    }

    /// Stops monitoring the network path.
    func invalidate() {
        guard isValid else { return }
        networkMonitor.cancel()
        isValid = false
    }

    /// A Boolean value indicating whether the network path is satisfied.
    var isSatisfied: Bool {
        currentPath.isSatisfied
    }

    /// Network path status change handler.
    func pathOnChange(_ handler: @escaping PathUpdateHandler) {
        networkPathUpdater = handler
    }
}
