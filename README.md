# NotchFocus

A Pomodoro timer that lives in your MacBook notch, like a Dynamic Island. Native SwiftUI, no dependencies.

- **Closed:** a progress ring and phase icon left of the camera, the countdown on the right. Nothing shows when idle.
- **Hover** to grow it a little; **click** to open the full timer; move away and it closes.
- **Open:** big ring, Focus / Short / Long picker, session dots, reset, play/pause, skip, +1 minute.
- **Banner** drops from the notch when a phase ends, with a shockwave, a chime and a haptic.
- **Light:** an optional border in the phase color (Settings › Colored border). When open and running, a comet of light sweeps back and forth along the border over a breathing aurora glow.
- **Settings** (gear icon): durations, long-break interval, auto-start, chime, launch at login.
- **Double-tap ⌥ Option** to open or close it from anywhere; click elsewhere to dismiss. (Toggle in Settings.)
- Right-click the notch for quick Start/Pause, Reset, Skip and Quit.
- On Macs without a notch it shows a small pill in the middle of the menu bar.

## Build

Needs macOS 14+ and the Xcode Command Line Tools.

```bash
./build.sh --run
```

The app is built to `build/NotchFocus.app`. Copy it to `/Applications` before turning on **Launch at login**.
