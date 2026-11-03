import AppKit
import Combine
import SwiftUI

/// A borderless panel that floats over the menu bar and never steals focus.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .mainMenu + 3
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets the first click on the notch register even though the app is never active.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class NotchWindowController {
    /// The window is a fixed canvas big enough for the largest state; the
    /// visible notch shape animates inside it, and clicks outside the shape
    /// fall through to whatever is underneath.
    private static let canvas = CGSize(width: 640, height: 320)

    private let panel: NotchPanel
    private let viewModel: NotchViewModel
    private var monitors: [Any] = []
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
        panel = NotchPanel(contentRect: NSRect(origin: .zero, size: Self.canvas))

        let root = NotchView(vm: viewModel, timer: viewModel.timer, settings: viewModel.settings)
        let host = FirstMouseHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: Self.canvas)
        panel.contentView = host

        reposition()
        panel.orderFrontRegardless()

        installMouseMonitors()

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.reposition() }
            .store(in: &cancellables)

        // Sizes change with mode and timer state; re-evaluate hit testing after each.
        viewModel.objectWillChange
            .merge(with: viewModel.timer.objectWillChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateHitTesting() }
            .store(in: &cancellables)
    }

    private var screen: NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func reposition() {
        let screen = screen
        let geo = Self.notchGeometry(for: screen)
        viewModel.notchSize = geo.size
        viewModel.hasNotch = geo.hasNotch

        let frame = screen.frame
        let origin = NSPoint(x: frame.midX - Self.canvas.width / 2,
                             y: frame.maxY - Self.canvas.height)
        panel.setFrame(NSRect(origin: origin, size: Self.canvas), display: true)
    }

    static func notchGeometry(for screen: NSScreen) -> (size: CGSize, hasNotch: Bool) {
        let top = screen.safeAreaInsets.top
        if top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            return (CGSize(width: width, height: top), true)
        }
        // No notch: draw a small pill in the middle of the menu bar.
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        return (CGSize(width: 150, height: max(24, menuBar)), false)
    }

    // MARK: Mouse

    private func installMouseMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.updateHitTesting() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.updateHitTesting() }
            return event
        }) {
            monitors.append(local)
        }
        // A global click always lands outside the notch (clicks inside go to the
        // panel), so it closes the notch, e.g. after it was opened with ⌥⌥.
        if let outside = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.viewModel.isExpanded else { return }
                self.viewModel.close()
            }
        }) {
            monitors.append(outside)
        }
    }

    private func updateHitTesting() {
        let frame = screen.frame
        let size = viewModel.size
        var rect = NSRect(x: frame.midX - size.width / 2,
                          y: frame.maxY - size.height,
                          width: size.width,
                          height: size.height)
        // A little slack below and to the sides makes the closed notch easy to hit.
        rect = rect.insetBy(dx: -4, dy: -4)

        let inside = rect.contains(NSEvent.mouseLocation)
        panel.ignoresMouseEvents = !inside
        viewModel.setHovering(inside)
    }
}
