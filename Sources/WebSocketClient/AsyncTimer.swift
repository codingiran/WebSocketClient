//
//  AsyncTimer.swift
//  WebSocketClient
//
//  Created by CodingIran on 2025/5/16.
//

import Foundation

final actor AsyncRepeatingTimer {
    typealias RepeatHandler = @Sendable () async -> Void
    typealias CancelHandler = @Sendable () async -> Void

    private var task: Task<Void, Error>?
    private var interval: TimeInterval
    private let priority: TaskPriority
    private let firesImmediately: Bool
    private var handler: RepeatHandler
    private var cancelHandler: CancelHandler?

    init(interval: TimeInterval,
         priority: TaskPriority = .medium,
         firesImmediately: Bool = true,
         handler: @escaping RepeatHandler,
         cancelHandler: CancelHandler? = nil)
    {
        self.interval = interval
        self.priority = priority
        self.firesImmediately = firesImmediately
        self.handler = handler
        self.cancelHandler = cancelHandler
    }

    // 启动定时器
    func start() {
        // 防止多次启动时没有清理
        stop()
        task = Task(priority: priority) {
            if !firesImmediately {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            do {
                while !Task.isCancelled {
                    await self.handler() // 执行异步任务
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            } catch is CancellationError {
                await cancelHandler?()
            } catch {}
        }
    }

    // 停止定时器
    func stop() {
        task?.cancel()
        task = nil
    }

    // 手动重启定时器
    func restart() {
        stop()
        start()
    }

    // 调整定时器间隔
    func setInterval(_ newInterval: TimeInterval) {
        interval = newInterval
        restart()
    }
}
