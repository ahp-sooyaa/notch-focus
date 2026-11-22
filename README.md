# NotchFocus

A Pomodoro timer that lives in your MacBook notch, like a Dynamic Island. Native SwiftUI and AppKit, no dependencies.

## Features

- **Closed:** a progress ring and phase icon left of the camera, the countdown on the right. Nothing shows when idle.
- **Hover** to grow it a little; **click** to open the full timer; move away and it closes.
- **Open:** big ring, Focus / Short / Long picker, session dots, reset, play/pause, skip, +1 minute.
- **Banner** drops from the notch when a phase ends, with a shockwave, a chime and a haptic.
- **Light:** an optional border in the phase color (Settings › Colored border). When open and running, a comet of light sweeps back and forth along the border over a breathing aurora glow.
- **Settings** (gear icon): durations, long-break interval, auto-start, chime, launch at login.
- **Double-tap ⌥ Option** to open or close it from anywhere; click elsewhere to dismiss. (Toggle in Settings.)
- Right-click the notch for quick Start/Pause, Reset, Skip and Quit.
- On Macs without a notch it shows a small pill in the middle of the menu bar.

## Requirements

- macOS 14 or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build and run

```bash
git clone https://github.com/ahp-sooyaa/notch-focus.git
cd notch-focus
./build.sh --run
```

The app is built to `build/NotchFocus.app`. Copy it to `/Applications` before turning on **Launch at login**.

### Permissions

None are required. The ⌥ Option double-tap works without any permission by polling the modifier state. If you grant Accessibility access, it listens for key events instead.

## How it works

| File | Role |
| --- | --- |
| `Sources/NotchWindowController.swift` | Borderless panel above the menu bar, sized from the screen's safe-area insets and the areas beside the notch; hover, click and click-outside monitors |
| `Sources/NotchShape.swift` | The animated outline that grows out of the notch |
| `Sources/NotchView.swift` | Closed, hover, open and banner layouts |
| `Sources/NotchEffects.swift` | Shockwave, coloured border, comet and aurora effects |
| `Sources/PomodoroTimer.swift` | Phases, sessions, auto-start |
| `Sources/NotchViewModel.swift` | State, chime and haptics |
| `Sources/DoubleTapMonitor.swift` | ⌥ Option double-tap, with or without Accessibility permission |
| `Sources/Settings.swift`, `SettingsView.swift` | Stored preferences and the Settings window |
| `scripts/make-icon.swift` | Draws the app icon |

## License

[MIT](LICENSE)
