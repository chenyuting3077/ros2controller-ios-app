import SwiftUI

struct JoystickPadView: View {
    let label: String
    let size: CGFloat
    var onChange: (CGPoint) -> Void

    @State private var thumbOffset: CGSize = .zero
    @State private var lastValue: CGPoint = .zero
    @State private var releaseTimer: Timer?

    private var padSize: CGFloat { size * 0.88 }
    private var radius: CGFloat { padSize / 2 }
    private var thumbRadius: CGFloat { padSize * 0.22 }
    private let dragDamping: CGFloat = 0.3
    private let releaseDuration: TimeInterval = 0.15
    private let releaseSteps = 12

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .overlay(Circle().stroke(Color(.systemGray3), lineWidth: 2))
                .frame(width: padSize, height: padSize)

            // Cross-hair lines
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: padSize * 0.8, height: 1)
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 1, height: padSize * 0.8)

            Circle()
                .fill(Color.white)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.95), lineWidth: 1.5)
                )
                .frame(width: thumbRadius * 2, height: thumbRadius * 2)
                .offset(thumbOffset)
                .shadow(color: Color.white.opacity(0.35), radius: 6)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .offset(y: padSize * 0.42)
        }
        .frame(width: size, height: size)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    releaseTimer?.invalidate()
                    releaseTimer = nil

                    let clamped = clamp(value.translation)
                    let damped = dampedOffset(from: thumbOffset, to: clamped)
                    let normalizedValue = normalized(damped)
                    thumbOffset = damped
                    lastValue = normalizedValue
                    onChange(normalizedValue)
                }
                .onEnded { _ in
                    startSmoothReturn()
                }
        )
    }

    private func startSmoothReturn() {
        releaseTimer?.invalidate()

        let startOffset = thumbOffset
        let startValue = lastValue
        guard startOffset != .zero || startValue != .zero else {
            onChange(.zero)
            return
        }

        var step = 0
        let interval = releaseDuration / Double(releaseSteps)
        releaseTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            step += 1
            let progress = min(Double(step) / Double(releaseSteps), 1.0)
            let remaining = 1.0 - progress

            thumbOffset = CGSize(
                width: startOffset.width * remaining,
                height: startOffset.height * remaining
            )

            let value = CGPoint(
                x: startValue.x * remaining,
                y: startValue.y * remaining
            )
            lastValue = value
            onChange(value)

            if progress >= 1.0 {
                timer.invalidate()
                releaseTimer = nil
                thumbOffset = .zero
                lastValue = .zero
                onChange(.zero)
            }
        }
    }

    private func dampedOffset(from current: CGSize, to target: CGSize) -> CGSize {
        CGSize(
            width: current.width + (target.width - current.width) * dragDamping,
            height: current.height + (target.height - current.height) * dragDamping
        )
    }

    private func clamp(_ translation: CGSize) -> CGSize {
        let x = translation.width
        let y = translation.height
        let dist = sqrt(x * x + y * y)
        let maxDist = radius
        if dist <= maxDist {
            return translation
        }
        let scale = maxDist / dist
        return CGSize(width: x * scale, height: y * scale)
    }

    private func normalized(_ offset: CGSize) -> CGPoint {
        let maxDist = radius
        guard maxDist > 0 else { return .zero }
        return CGPoint(
            x: Double(offset.width / maxDist),
            y: Double(-offset.height / maxDist)   // flip Y: up = positive
        )
    }
}
