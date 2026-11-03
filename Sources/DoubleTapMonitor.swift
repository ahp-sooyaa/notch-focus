import AppKit
import ApplicationServices

/// Fires when ⌥ Option is tapped twice quickly on its own.
///
/// Watching modifier keys in other apps needs Accessibility permission. When the
/// app has it, this listens to flagsChanged events; otherwise it falls back to
/// polling the current modifier state, which needs no permission.
@MainActor
final class DoubleTapMonitor {
    var onDoubleTap: () -> Void

    private let maxHold: TimeInterval = 0.3
    private let maxGap: TimeInterval = 0.4

    private var optionWasDown = false
    private var optionDownAt: Date?
    private var lastTapAt: Date?

    private var monitors: [Any] = []
    private var poller: Timer?

    init(onDoubleTap: @escaping () -> Void) {
        self.onDoubleTap = onDoubleTap
    }

    var isRunning: Bool { !monitors.isEmpty || poller != nil }

    func start() {
        guard !isRunning else { return }
        if AXIsProcessTrusted() {
            startEventMonitors()
        } else {
            startPolling()
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        poller?.invalidate()
        poller = nil
        reset()
    }

    private func startEventMonitors() {
        let flags: (NSEvent) -> Void = { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event.modifierFlags) }
        }
        // Typing a key between taps (e.g. ⌥E twice) shouldn't count.
        let keyDown: (NSEvent) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.reset() }
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: flags) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keyDown) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { flags($0); return $0 }) { monitors.append(m) }
    }

    private func startPolling() {
        let t = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.handle(NSEvent.modifierFlags) }
        }
        t.tolerance = 0.01
        RunLoop.main.add(t, forMode: .common)
        poller = t
    }

    private func handle(_ rawFlags: NSEvent.ModifierFlags) {
        let flags = rawFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        let optionOnly = flags == .option
        let now = Date()

        if optionOnly && !optionWasDown {
            optionDownAt = now
        } else if !optionOnly && optionWasDown {
            // A tap is a short press of Option alone, released cleanly.
            if flags.isEmpty, let down = optionDownAt, now.timeIntervalSince(down) < maxHold {
                if let last = lastTapAt, now.timeIntervalSince(last) < maxGap {
                    lastTapAt = nil
                    onDoubleTap()
                } else {
                    lastTapAt = now
                }
            } else {
                lastTapAt = nil
            }
            optionDownAt = nil
        } else if !flags.isEmpty && !optionOnly {
            lastTapAt = nil
        }
        optionWasDown = optionOnly
    }

    private func reset() {
        optionDownAt = nil
        lastTapAt = nil
    }
}
