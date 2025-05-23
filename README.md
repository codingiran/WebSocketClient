# WebSocketClient

A Swift WebSocket client library for Apple platforms with built-in reconnection, auto-ping, and network monitoring support.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2013.0+%20%7C%20macOS%2010.15+%20%7C%20tvOS%2013.0+%20%7C%20watchOS%206.0+%20%7C%20visionOS%201.0+-lightgray.svg)](https://developer.apple.com)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager)
[![License](https://img.shields.io/badge/license-MIT-black.svg)](https://opensource.org/licenses/MIT)

## Features

- ✅ Swift Concurrency support with async/await
- ✅ Multiple WebSocket engines support (TCP Transport and URLSession)
- ✅ Automatic reconnection with customizable strategies
- ✅ Network path monitoring with automatic reconnection
- ✅ Auto-ping support for connection keep-alive
- ✅ Comprehensive logging system
- ✅ Support for all Apple platforms (iOS, macOS, tvOS, watchOS, visionOS)
- ✅ Swift Package Manager integration

## Requirements

- iOS 13.0+ | macOS 10.15+ | tvOS 13.0+ | watchOS 6.0+ | visionOS 1.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following line to your `Package.swift` file's dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/codingiran/WebSocketClient.git", from: "0.0.1")
]
```

Or add the dependency through Xcode:

1. File > Add Package Dependencies
2. Search for `https://github.com/codingiran/WebSocketClient.git`
3. Select "Up to Next Major Version" with "0.0.1"

## Usage

### Basic Connection

```swift
let client = WebSocketClient(url: URL(string: "wss://echo.websocket.org")!,
                            connectionHeader: ["Authorization": "Bearer token"])

// Connect to the WebSocket server
await client.connect()

// Send a text message
await client.send(.text("Hello, WebSocket!"))

// Send binary data
await client.send(.binary(Data()))

// Disconnect
await client.disconnect(closeCode: .normalClosure)

// Force disconnect
await client.forceDisconnect()

```

### Delegate Implementation

```swift
class WebSocketHandler: WebSocketClient.Delegate {
    func webSocketClient(_ client: WebSocketClient, didUpdate state: WebSocketClient.State) {
        print("WebSocket state changed to: \(state)")
    }
    
    func webSocketClient(_ client: WebSocketClient, didReceive event: WebSocketClient.Event) {
        switch event {
        case .text(let message):
            print("Received text message: \(message)")
        case .binary(let data):
            print("Received binary data: \(data)")
        default:
            break
        }
    }
}
```

### Auto-Ping Configuration

```swift
let client = WebSocketClient(url: URL(string: "wss://echo.websocket.org")!,
                            autoPingInterval: 30, // Send ping every 30 seconds
                            connectionHeader: [:])
```

### Custom Reconnection Strategy

```swift

/// Exponential backoff strategy
let strategy = WebSocketClient.ExponentialReconnectStrategy(
    exponentialBackoffBase: 2,
    exponentialBackoffScale: 0.5,
    maxRetryCount: 5,
    maxRetryInterval: 60,
    delayJitter: 0.2
)

let client = WebSocketClient(url: URL(string: "wss://echo.websocket.org")!,
                            connectionHeader: [:],
                            reconnectStrategy: strategy)
```

### Engine Selection

```swift
// Using TCP Transport (Default)
let tcpClient = WebSocketClient(url: url,
                               connectionHeader: [:],
                               engine: .tcpTransport)

// Using URLSession
let urlSessionClient = WebSocketClient(url: url,
                                      connectionHeader: [:],
                                      engine: .urlSession)
```

## Advanced Features

### Network Path Monitoring

The client automatically monitors network connectivity and handles reconnection:

```swift
let client = WebSocketClient(url: url,
                            connectionHeader: [:],
                            networkMonitorDebounceInterval: 1.0) // 1 second debounce

// Implement the delegate method
func webSocketClient(_ client: WebSocketClient, didMonitorNetworkPathChange path: NWPath) {
    print("Network path changed: \(path.status)")
}
```

### Logging System

```swift
func webSocketClient(_ client: WebSocketClient, didOutput log: WebSocketClient.Log) {
    switch log.level {
    case .debug:
        print("[Debug] \(log.message)")
    case .error:
        print("[Error] \(log.message)")
    default:
        break
    }
}
```

## License

WebSocketClient is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
