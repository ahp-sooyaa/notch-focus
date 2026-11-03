import Foundation
import ServiceManagement

/// User preferences, persisted in UserDefaults.
@MainActor
final class Settings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var focusMinutes: Int { didSet { save("focusMinutes", focusMinutes) } }
    @Published var shortBreakMinutes: Int { didSet { save("shortBreakMinutes", shortBreakMinutes) } }
    @Published var longBreakMinutes: Int { didSet { save("longBreakMinutes", longBreakMinutes) } }
    @Published var sessionsBeforeLongBreak: Int { didSet { save("sessionsBeforeLongBreak", sessionsBeforeLongBreak) } }
    @Published var autoStartBreaks: Bool { didSet { save("autoStartBreaks", autoStartBreaks) } }
    @Published var autoStartFocus: Bool { didSet { save("autoStartFocus", autoStartFocus) } }
    @Published var soundEnabled: Bool { didSet { save("soundEnabled", soundEnabled) } }
    @Published var doubleTapOption: Bool { didSet { save("doubleTapOption", doubleTapOption) } }
    @Published var coloredBorder: Bool { didSet { save("coloredBorder", coloredBorder) } }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("NotchFocus: launch at login failed: \(error)")
            }
        }
    }

    /// Called whenever a duration changes, so an idle timer can pick up the new length.
    var onDurationsChanged: (() -> Void)?

    init() {
        defaults.register(defaults: [
            "focusMinutes": 25,
            "shortBreakMinutes": 5,
            "longBreakMinutes": 15,
            "sessionsBeforeLongBreak": 4,
            "autoStartBreaks": true,
            "autoStartFocus": false,
            "soundEnabled": true,
            "doubleTapOption": true,
            "coloredBorder": true,
        ])
        focusMinutes = defaults.integer(forKey: "focusMinutes")
        shortBreakMinutes = defaults.integer(forKey: "shortBreakMinutes")
        longBreakMinutes = defaults.integer(forKey: "longBreakMinutes")
        sessionsBeforeLongBreak = defaults.integer(forKey: "sessionsBeforeLongBreak")
        autoStartBreaks = defaults.bool(forKey: "autoStartBreaks")
        autoStartFocus = defaults.bool(forKey: "autoStartFocus")
        soundEnabled = defaults.bool(forKey: "soundEnabled")
        doubleTapOption = defaults.bool(forKey: "doubleTapOption")
        coloredBorder = defaults.bool(forKey: "coloredBorder")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func minutes(for phase: Phase) -> Int {
        switch phase {
        case .focus: focusMinutes
        case .shortBreak: shortBreakMinutes
        case .longBreak: longBreakMinutes
        }
    }

    private func save(_ key: String, _ value: Any) {
        defaults.set(value, forKey: key)
        if key.hasSuffix("Minutes") { onDurationsChanged?() }
    }
}
