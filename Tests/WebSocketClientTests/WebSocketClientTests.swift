@testable import WebSocketClient
import XCTest
import Network

final class WebSocketClientTests: XCTestCase {
    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
        
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            let currentPath = monitor.currentPath
            debugPrint(path)
        }
        monitor.start(queue: .global())
        let currentPath = monitor.currentPath
        debugPrint(currentPath)
        
    }
}
