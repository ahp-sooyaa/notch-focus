import SwiftUI

struct SettingsView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                HeaderButton(symbol: "checkmark", help: "Done") { vm.open() }
            }
            .padding(.horizontal, 6)
            .frame(height: max(vm.notchSize.height, 24))

            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 8) {
                    MinuteStepper(title: "Focus", value: $settings.focusMinutes, range: 1...120, unit: "min", color: Phase.focus.color)
                    MinuteStepper(title: "Short break", value: $settings.shortBreakMinutes, range: 1...60, unit: "min", color: Phase.shortBreak.color)
                    MinuteStepper(title: "Long break", value: $settings.longBreakMinutes, range: 1...90, unit: "min", color: Phase.longBreak.color)
                    MinuteStepper(title: "Long break every", value: $settings.sessionsBeforeLongBreak, range: 1...12, unit: "", color: .white)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 9) {
                    SettingToggle(title: "Auto-start breaks", isOn: $settings.autoStartBreaks)
                    SettingToggle(title: "Auto-start focus", isOn: $settings.autoStartFocus)
                    SettingToggle(title: "Chime", isOn: $settings.soundEnabled)
                    SettingToggle(title: "Colored border", isOn: $settings.coloredBorder)
                    SettingToggle(title: "Double-tap ⌥ to open", isOn: $settings.doubleTapOption)
                    SettingToggle(title: "Launch at login", isOn: $settings.launchAtLogin)
                    Spacer(minLength: 0)
                    Button { NSApp.terminate(nil) } label: {
                        Label("Quit NotchFocus", systemImage: "power")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 170)
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
    }
}

private struct MinuteStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
            Spacer(minLength: 4)
            step("minus", -1)
            Text(unit.isEmpty ? "\(value)" : "\(value) \(unit)")
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .frame(width: 44)
            step("plus", 1)
        }
    }

    private func step(_ symbol: String, _ delta: Int) -> some View {
        Button {
            value = min(range.upperBound, max(range.lowerBound, value + delta))
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .bold))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }
}

private struct SettingToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(NotchSwitchStyle())
    }
}

private struct NotchSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label
                Capsule()
                    .fill(configuration.isOn ? Phase.shortBreak.color : Color.white.opacity(0.15))
                    .frame(width: 28, height: 16)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(.white).padding(2)
                    }
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
