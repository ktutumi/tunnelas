import AppKit
import Foundation

final class SystemSleepWakeObserver {
    var onSleep: (() -> Void)?
    var onWake: (() -> Void)?

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onSleep?()
        }
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onWake?()
        }
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        if let sleepObserver {
            center.removeObserver(sleepObserver)
        }
        if let wakeObserver {
            center.removeObserver(wakeObserver)
        }
        sleepObserver = nil
        wakeObserver = nil
    }
}

