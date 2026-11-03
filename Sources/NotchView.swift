import SwiftUI

struct NotchView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var timer: PomodoroTimer
    @ObservedObject var settings: Settings

    private let spring = Animation.spring(response: 0.42, dampingFraction: 0.8)

    var body: some View {
        let size = vm.size
        let r = vm.radii
        let shape = NotchShape(topRadius: r.top, bottomRadius: r.bottom)

        ZStack(alignment: .top) {
            shape.fill(Color.black)

            if vm.mode != .closed || timer.hasStarted {
                NotchEffects(topRadius: r.top,
                             bottomRadius: r.bottom,
                             color: timer.phase.color,
                             lineWidth: vm.mode == .closed ? 1 : 1.5,
                             showsBorder: settings.coloredBorder,
                             animating: (vm.mode == .open && timer.isRunning) || vm.mode == .banner,
                             showsAurora: vm.mode == .open || vm.mode == .banner)
                    .transition(.opacity)
            }

            content
                .padding(.horizontal, r.top)
                .frame(width: size.width, height: size.height, alignment: .top)
                .transition(.blurReplace.combined(with: .opacity))
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .contentShape(shape)
        .shadow(color: .black.opacity(vm.mode == .closed ? 0 : 0.45), radius: 14, y: 6)
        .onTapGesture {
            if vm.mode == .closed || vm.mode == .banner { vm.open() }
        }
        .contextMenu {
            Button(timer.isRunning ? "Pause" : "Start") { timer.toggle() }
            Button("Reset") { timer.reset() }
            Button("Skip to Next Phase") { timer.skip() }
            Divider()
            Button("Quit NotchFocus") { NSApp.terminate(nil) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(spring, value: vm.mode)
        .animation(spring, value: vm.hovering)
        .animation(spring, value: timer.hasStarted)
        .animation(.easeInOut(duration: 0.3), value: settings.coloredBorder)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        switch vm.mode {
        case .closed:
            ClosedView(vm: vm, timer: timer)
        case .open:
            ExpandedView(vm: vm, timer: timer)
        case .settings:
            SettingsView(vm: vm, settings: settings)
        case .banner:
            if let banner = vm.banner {
                BannerView(vm: vm, timer: timer, info: banner)
            }
        }
    }
}

// MARK: - Closed

private struct ClosedView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var timer: PomodoroTimer

    var body: some View {
        HStack(spacing: 0) {
            if timer.hasStarted {
                HStack(spacing: 6) {
                    ProgressRing(progress: timer.progress, color: timer.phase.color, lineWidth: 2.5)
                        .frame(width: 14, height: 14)
                    Image(systemName: timer.isRunning ? timer.phase.symbol : "pause.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(timer.phase.color)
                }
                .frame(width: vm.sideWidth - 8, alignment: .leading)

                Spacer(minLength: 0)

                Text(timer.remainingText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(timer.isRunning ? .white : .white.opacity(0.5))
                    .contentTransition(.numericText(countsDown: true))
                    .frame(width: vm.sideWidth - 8, alignment: .trailing)
            } else if !vm.hasNotch {
                // No camera housing to hide behind, so say what this pill is.
                Spacer()
                Label("Focus", systemImage: "timer")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .frame(height: vm.notchSize.height)
    }
}

// MARK: - Expanded

private struct ExpandedView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var timer: PomodoroTimer

    var body: some View {
        VStack(spacing: 0) {
            // Header sits beside the camera, leaving the middle clear.
            HStack {
                Label("\(timer.completedToday) today", systemImage: "flame.fill")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                HeaderButton(symbol: "gearshape.fill", help: "Settings") { vm.openSettings() }
            }
            .padding(.horizontal, 6)
            .frame(height: max(vm.notchSize.height, 24))

            HStack(spacing: 22) {
                ZStack {
                    ProgressRing(progress: timer.progress, color: timer.phase.color, lineWidth: 7)
                    VStack(spacing: 2) {
                        Text(timer.remainingText)
                            .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText(countsDown: true))
                        Text(timer.phase.title.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .kerning(0.8)
                            .foregroundStyle(timer.phase.color)
                    }
                }
                .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 14) {
                    PhasePicker(timer: timer)
                    SessionDots(completed: timer.completedInCycle,
                                total: max(1, timer.settings.sessionsBeforeLongBreak),
                                color: Phase.focus.color)
                    HStack(spacing: 10) {
                        RoundButton(symbol: "arrow.counterclockwise", size: 30, help: "Reset") { timer.reset() }
                        RoundButton(symbol: timer.isRunning ? "pause.fill" : "play.fill",
                                    size: 44, tint: timer.phase.color, help: timer.isRunning ? "Pause" : "Start") {
                            timer.toggle()
                        }
                        .background {
                            if timer.isRunning { PulseHalo(color: timer.phase.color) }
                        }
                        RoundButton(symbol: "forward.end.fill", size: 30, help: "Skip") { timer.skip() }
                        RoundButton(symbol: "plus", label: "1m", size: 30, help: "Add a minute") { timer.addMinute() }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
        }
    }
}

private struct PhasePicker: View {
    @ObservedObject var timer: PomodoroTimer

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Phase.allCases, id: \.self) { phase in
                let selected = phase == timer.phase
                Button { timer.select(phase) } label: {
                    Text(phase.shortTitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(selected ? Color.black : Color.white.opacity(0.7))
                        .background(Capsule().fill(selected ? phase.color : Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SessionDots: View {
    let completed: Int
    let total: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < completed ? color : Color.white.opacity(0.15))
                    .frame(width: 7, height: 7)
            }
            Text("\(min(completed, total))/\(total) until long break")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 2)
        }
    }
}

// MARK: - Banner

private struct BannerView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var timer: PomodoroTimer
    let info: BannerInfo

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: vm.notchSize.height)
            HStack(spacing: 12) {
                Image(systemName: info.next.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(info.next.color)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(info.next.color.opacity(0.18)))
                    .background(Shockwave(color: info.next.color))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(subtitle)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)

                if timer.isRunning {
                    PillButton(title: "Skip", tint: .white.opacity(0.15), dark: false) {
                        timer.skip()
                        vm.close()
                    }
                } else {
                    PillButton(title: "Start", tint: info.next.color, dark: true) {
                        timer.start()
                        vm.close()
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
        }
    }

    private var title: String {
        info.finished == .focus ? "Focus session done" : "Break's over"
    }

    private var subtitle: String {
        let minutes = timer.settings.minutes(for: info.next)
        switch info.next {
        case .focus: return "Ready for \(minutes) minutes of focus?"
        case .shortBreak: return "Take a \(minutes)-minute break"
        case .longBreak: return "You earned a \(minutes)-minute long break"
        }
    }
}

// MARK: - Controls

struct RoundButton: View {
    let symbol: String
    var label: String? = nil
    var size: CGFloat
    var tint: Color? = nil
    var help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let label {
                    HStack(spacing: 1) {
                        Image(systemName: symbol).font(.system(size: 8, weight: .bold))
                        Text(label).font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.38, weight: .semibold))
                }
            }
            .foregroundStyle(tint == nil ? Color.white : Color.black)
            .frame(width: size, height: size)
            .background(Circle().fill(tint ?? Color.white.opacity(hovering ? 0.18 : 0.1)))
            .scaleEffect(hovering ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

struct HeaderButton: View {
    let symbol: String
    var help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct PillButton: View {
    let title: String
    let tint: Color
    let dark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(dark ? Color.black : Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(tint))
        }
        .buttonStyle(.plain)
    }
}
