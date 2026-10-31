import Foundation
import Network

/// Anything that can say whether the device has a network path (tests stub it)
protocol ConnectivityChecking: AnyObject {
    var isOnline: Bool { get }
}

/// Watches the network path, so the app can skip requests that can't succeed and use what is on the device.
/// `isOnline` is safe to read from any thread; `isConnected` is the same value published on the main thread for views.
final class ConnectivityMonitor: ObservableObject, ConnectivityChecking, @unchecked Sendable {
    static let shared = ConnectivityMonitor()

    @Published private(set) var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "tilo.BookBite.connectivity")
    private let lock = NSLock()
    // Online until the first path update, so a slow monitor never blocks a request
    private var online = true

    var isOnline: Bool {
        lock.lock()
        defer { lock.unlock() }
        return online
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.update(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    private func update(_ isOnline: Bool) {
        lock.lock()
        let changed = online != isOnline
        online = isOnline
        lock.unlock()

        guard changed else { return }
        if AppConfiguration.shared.isLoggingEnabled {
            print("📶 ConnectivityMonitor: \(isOnline ? "online" : "offline")")
        }
        DispatchQueue.main.async { self.isConnected = isOnline }
    }
}

extension URLError {
    /// The device has no usable connection: retrying soon can't help
    var isOffline: Bool {
        switch code {
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff, .callIsActive:
            return true
        default:
            return false
        }
    }
}
