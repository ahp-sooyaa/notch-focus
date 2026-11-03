import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchWindowController?
    private var settings: Settings?
    private var timer: PomodoroTimer?
    private var viewModel: NotchViewModel?
    private var doubleTap: DoubleTapMonitor?
    private var settingsObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = Settings()
        let timer = PomodoroTimer(settings: settings)
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
        let geo = NotchWindowController.notchGeometry(for: screen)
        let vm = NotchViewModel(timer: timer, settings: settings, notchSize: geo.size, hasNotch: geo.hasNotch)

        timer.onPhaseComplete = { [weak vm, weak settings] finished, next in
            if settings?.soundEnabled == true {
                NSSound(named: finished == .focus ? "Glass" : "Hero")?.play()
            }
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
            vm?.showBanner(BannerInfo(finished: finished, next: next))
        }

        self.settings = settings
        self.timer = timer
        self.viewModel = vm
        controller = NotchWindowController(viewModel: vm)

        let doubleTap = DoubleTapMonitor { [weak vm] in vm?.toggle() }
        self.doubleTap = doubleTap
        settingsObserver = settings.$doubleTapOption.sink { enabled in
            enabled ? doubleTap.start() : doubleTap.stop()
        }
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
