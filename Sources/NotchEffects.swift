import SwiftUI

/// Light effects drawn inside the notch, under its content:
/// - an optional border in the phase color;
/// - while `animating`, a comet of light glides back and forth along the
///   border and a soft aurora breathes up from the bottom edge.
///
/// The per-frame timeline only runs while `animating`, so the closed notch
/// stays idle.
struct NotchEffects: View {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var color: Color
    var lineWidth: CGFloat
    var showsBorder: Bool
    var animating: Bool
    var showsAurora: Bool

    var body: some View {
        let border = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, closed: false)

        ZStack {
            if showsAurora {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !animating)) { ctx in
                    Aurora(color: color, time: ctx.date.timeIntervalSinceReferenceDate)
                }
            }

            if showsBorder {
                // The stroke is centered on the clip edge, so draw it double width.
                border
                    .stroke(color.opacity(0.85), lineWidth: lineWidth * 2)
                    .shadow(color: color, radius: 4)
                    .transition(.opacity)
            }

            if animating {
                TimelineView(.animation(minimumInterval: 1 / 60)) { ctx in
                    Comet(border: border, color: color, lineWidth: lineWidth,
                          time: ctx.date.timeIntervalSinceReferenceDate)
                }
                .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
    }
}

/// A bright head with a fading tail that sweeps along the border and back.
private struct Comet: View {
    let border: NotchShape
    let color: Color
    let lineWidth: CGFloat
    let time: TimeInterval

    private let period: TimeInterval = 3.6
    private let length = 0.22
    private let segments = 14

    var body: some View {
        let (head, direction) = position

        // Overlapping strokes that all start at the head: opacity piles up near
        // the head and thins toward the tail, giving a smooth streak.
        let trail = ZStack {
            ForEach(0..<segments, id: \.self) { i in
                let tail = head - direction * length * Double(i + 1) / Double(segments)
                let fade = 1 - Double(i) / Double(segments)
                border
                    .trim(from: clamp(min(head, tail)), to: clamp(max(head, tail)))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth * 2 * (0.8 + 1.4 * fade), lineCap: .butt))
                    .opacity(0.22)
            }
            border
                .trim(from: clamp(head - 0.012), to: clamp(head + 0.012))
                .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth * 3, lineCap: .round))
        }

        ZStack {
            trail.blur(radius: 8).opacity(0.9)
            trail
        }
        .blendMode(.plusLighter)
    }

    /// Ping-pong along the path with eased turns. Overshoots 0...1 a little so
    /// the tail slips fully off each end before coming back.
    private var position: (head: Double, direction: Double) {
        let u = (time / period).truncatingRemainder(dividingBy: 1)
        let leg = u < 0.5 ? u * 2 : 2 - u * 2
        let eased = leg * leg * (3 - 2 * leg)
        let overshoot = length * 0.6
        let head = -overshoot + eased * (1 + overshoot * 2)
        return (head, u < 0.5 ? 1 : -1)
    }

    private func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
}

/// A soft colored glow rising from the bottom edge, slowly breathing.
private struct Aurora: View {
    let color: Color
    let time: TimeInterval

    var body: some View {
        let breath = 0.5 + 0.5 * sin(time * 2 * .pi / 4.5)
        let drift = sin(time * 2 * .pi / 9) * 0.18

        GeometryReader { geo in
            ZStack {
                Ellipse()
                    .fill(color.opacity(0.16 + 0.12 * breath))
                    .frame(width: geo.size.width * 0.7, height: geo.size.height * 0.55)
                    .position(x: geo.size.width * (0.5 + drift), y: geo.size.height * 1.02)
                Ellipse()
                    .fill(color.opacity(0.08 + 0.08 * (1 - breath)))
                    .frame(width: geo.size.width * 0.45, height: geo.size.height * 0.4)
                    .position(x: geo.size.width * (0.5 - drift * 1.4), y: geo.size.height * 1.0)
            }
            .blur(radius: 34)
        }
    }
}

/// Rings that ripple out from a view, e.g. when a phase ends.
struct Shockwave: View {
    let color: Color
    var rings = 3
    @State private var fired = false

    var body: some View {
        ZStack {
            ForEach(0..<rings, id: \.self) { i in
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .scaleEffect(fired ? 2.8 : 1)
                    .opacity(fired ? 0 : 0.7)
                    .animation(.easeOut(duration: 1.5).delay(Double(i) * 0.22), value: fired)
            }
        }
        .allowsHitTesting(false)
        .onAppear { fired = true }
    }
}

/// A heartbeat halo for the play button while the timer runs.
struct PulseHalo: View {
    let color: Color

    var body: some View {
        PhaseAnimator([false, true]) { expanded in
            Circle()
                .stroke(color, lineWidth: 2)
                .scaleEffect(expanded ? 1.45 : 1)
                .opacity(expanded ? 0 : 0.6)
        } animation: { expanded in
            expanded ? .easeOut(duration: 1.6) : nil
        }
        .allowsHitTesting(false)
    }
}
