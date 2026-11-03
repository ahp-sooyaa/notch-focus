import AppKit
import SwiftUI

struct BannerInfo: Equatable {
    let finished: Phase
    let next: Phase
}

/// UI state for the notch: which mode it's in and how big it should be.
@MainActor
final class NotchViewModel: ObservableObject {
    enum Mode: Equatable { case closed, open, settings, banner }

    @Published private(set) var mode: Mode = .closed
    @Published private(set) var hovering = false
    @Published private(set) var banner: BannerInfo?
    @Published var notchSize: CGSize
    @Published var hasNotch: Bool

    let timer: PomodoroTimer
    let settings: Settings

    /// Width of each status area beside the camera when the notch is closed.
    let sideWidth: CGFloat = 62

    private var closeTask: Task<Void, Never>?
    private var bannerTask: Task<Void, Never>?

    init(timer: PomodoroTimer, settings: Settings, notchSize: CGSize, hasNotch: Bool) {
        self.timer = timer
        self.settings = settings
        self.notchSize = notchSize
        self.hasNotch = hasNotch
    }

    // MARK: Geometry

    var size: CGSize {
        let n = notchSize
        switch mode {
        case .closed:
            if timer.hasStarted {
                return CGSize(width: n.width + sideWidth * 2 + (hovering ? 12 : 0),
                              height: n.height + (hovering ? 4 : 0))
            }
            return CGSize(width: n.width + (hovering ? 24 : 0),
                          height: n.height + (hovering ? 6 : 0))
        case .open:
            return CGSize(width: 470, height: n.height + 150)
        case .settings:
            return CGSize(width: 470, height: n.height + 222)
        case .banner:
            return CGSize(width: 420, height: n.height + 68)
        }
    }

    /// (top ear radius, bottom corner radius)
    var radii: (top: CGFloat, bottom: CGFloat) {
        switch mode {
        case .closed: (6, hasNotch ? 10 : 12)
        case .banner: (10, 22)
        case .open, .settings: (14, 28)
        }
    }

    // MARK: Transitions

    func open() {
        cancelTimers()
        timer.refreshDay()
        banner = nil
        mode = .open
    }

    /// Keyboard shortcut: open the timer, or close it if it's already open.
    func toggle() {
        switch mode {
        case .open, .settings: close()
        case .closed, .banner: open()
        }
    }

    var isExpanded: Bool { mode != .closed }

    func openSettings() {
        cancelTimers()
        mode = .settings
    }

    func close() {
        cancelTimers()
        banner = nil
        mode = .closed
    }

    func showBanner(_ info: BannerInfo) {
        guard mode == .closed || mode == .banner else { return }
        banner = info
        mode = .banner
        scheduleBannerDismiss(after: 6)
    }

    func setHovering(_ inside: Bool) {
        guard inside != hovering else { return }
        hovering = inside

        if inside {
            closeTask?.cancel()
            if mode == .closed {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            if mode == .banner { bannerTask?.cancel() }
            return
        }

        switch mode {
        case .open, .settings:
            closeTask?.cancel()
            closeTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                self?.close()
            }
        case .banner:
            scheduleBannerDismiss(after: 1.5)
        case .closed:
            break
        }
    }

    private func scheduleBannerDismiss(after seconds: Double) {
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.mode == .banner, !self.hovering else { return }
            self.close()
        }
    }

    private func cancelTimers() {
        closeTask?.cancel()
        bannerTask?.cancel()
    }
}
