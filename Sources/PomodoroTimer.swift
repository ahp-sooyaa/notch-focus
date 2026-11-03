import AppKit
import SwiftUI

enum Phase: String, CaseIterable {
    case focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    var shortTitle: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short"
        case .longBreak: "Long"
        }
    }

    var symbol: String {
        switch self {
        case .focus: "brain.head.profile"
        case .shortBreak: "cup.and.saucer.fill"
        case .longBreak: "figure.walk"
        }
    }

    var color: Color {
        switch self {
        case .focus: Color(red: 1.0, green: 0.38, blue: 0.33)
        case .shortBreak: Color(red: 0.30, green: 0.85, blue: 0.55)
        case .longBreak: Color(red: 0.35, green: 0.65, blue: 1.0)
        }
    }
}

/// The pomodoro state machine. Time is derived from an end date, so sleep and
/// timer drift never skew the countdown.
@MainActor
final class PomodoroTimer: ObservableObject {
    @Published private(set) var phase: Phase = .focus
    @Published private(set) var isRunning = false
    /// True once the current phase has been started (running or paused mid-way).
    @Published private(set) var hasStarted = false
    @Published private(set) var remaining: TimeInterval = 0
    /// Focus sessions finished in the current cycle (resets after a long break
    /// and at the start of each day).
    @Published private(set) var completedInCycle = 0 {
        didSet { defaults.set(completedInCycle, forKey: "cycleCount") }
    }
    @Published private(set) var completedToday = 0

    /// (finished phase, next phase)
    var onPhaseComplete: ((Phase, Phase) -> Void)?

    let settings: Settings
    private var endDate: Date?
    private var ticker: Timer?
    private var dayObservers: [NSObjectProtocol] = []

    private let defaults = UserDefaults.standard
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(settings: Settings) {
        self.settings = settings
        remaining = duration
        loadStats()
        settings.onDurationsChanged = { [weak self] in
            guard let self, !self.hasStarted else { return }
            self.remaining = self.duration
        }

        // The app runs for days at a time, so catch midnight and waking from sleep.
        let refresh: (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshDay() }
        }
        dayObservers = [
            NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main, using: refresh),
            NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: refresh),
        ]
    }

    var duration: TimeInterval { TimeInterval(settings.minutes(for: phase) * 60) }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / duration))
    }

    var remainingText: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: Controls

    func start() {
        guard !isRunning else { return }
        if remaining <= 0 { remaining = duration }
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        hasStarted = true
        startTicker()
    }

    func pause() {
        guard isRunning else { return }
        tick()
        isRunning = false
        endDate = nil
        stopTicker()
    }

    func toggle() { isRunning ? pause() : start() }

    func reset() {
        stopTicker()
        isRunning = false
        hasStarted = false
        endDate = nil
        remaining = duration
    }

    /// Ends the current phase now, without counting it as a completed session.
    func skip() { advance(countSession: false, notify: false) }

    func addMinute() {
        remaining += 60
        if let end = endDate { endDate = end.addingTimeInterval(60) }
    }

    func select(_ newPhase: Phase) {
        guard newPhase != phase || hasStarted else { return }
        phase = newPhase
        reset()
    }

    // MARK: Internals

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 { advance(countSession: true, notify: true) }
    }

    private func advance(countSession: Bool, notify: Bool) {
        let finished = phase
        let next: Phase
        switch finished {
        case .focus:
            if countSession {
                completedInCycle += 1
                recordCompletedSession()
            }
            let cycle = max(1, settings.sessionsBeforeLongBreak)
            next = completedInCycle >= cycle ? .longBreak : .shortBreak
        case .shortBreak:
            next = .focus
        case .longBreak:
            completedInCycle = 0
            next = .focus
        }

        phase = next
        reset()
        if notify { onPhaseComplete?(finished, next) }

        let autoStart = next == .focus ? settings.autoStartFocus : settings.autoStartBreaks
        if notify && autoStart { start() }
    }

    private func loadStats() {
        completedToday = defaults.integer(forKey: "statsCount")
        completedInCycle = defaults.integer(forKey: "cycleCount")
        refreshDay()
    }

    /// Starts a fresh day's count (and a fresh cycle) once the date has moved on.
    func refreshDay(now: Date = Date()) {
        let today = Self.dayFormatter.string(from: now)
        guard defaults.string(forKey: "statsDay") != today else { return }
        defaults.set(today, forKey: "statsDay")
        completedToday = 0
        defaults.set(0, forKey: "statsCount")
        completedInCycle = 0
    }

    private func recordCompletedSession() {
        refreshDay()
        completedToday += 1
        defaults.set(completedToday, forKey: "statsCount")
    }
}
