import SwiftUI

struct JoystickPadView: View {
    let label: String
    let size: CGFloat
    var onChange: (CGPoint) -> Void

    @State private var thumbOffset: CGSize = .zero

    private var radius: CGFloat { size / 2 }
    private var thumbRadius: CGFloat { size * 0.22 }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .overlay(Circle().stroke(Color(.systemGray3), lineWidth: 2))
                .frame(width: size, height: size)

            // Cross-hair lines
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: size * 0.8, height: 1)
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 1, height: size * 0.8)

            Circle()
                .fill(Color.accentColor.opacity(0.85))
                .frame(width: thumbRadius * 2, height: thumbRadius * 2)
                .offset(thumbOffset)
                .shadow(radius: 4)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .offset(y: size * 0.42)
        }
        .frame(width: size, height: size)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let clamped = clamp(value.translation)
                    thumbOffset = clamped
                    onChange(normalized(clamped))
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2)) {
                        thumbOffset = .zero
                    }
                    onChange(.zero)
                }
        )
    }

    private func clamp(_ translation: CGSize) -> CGSize {
        let x = translation.width
        let y = translation.height
        let dist = sqrt(x * x + y * y)
        let maxDist = radius - thumbRadius
        if dist <= maxDist {
            return translation
        }
        let scale = maxDist / dist
        return CGSize(width: x * scale, height: y * scale)
    }

    private func normalized(_ offset: CGSize) -> CGPoint {
        let maxDist = radius - thumbRadius
        guard maxDist > 0 else { return .zero }
        return CGPoint(
            x: Double(offset.width / maxDist),
            y: Double(-offset.height / maxDist)   // flip Y: up = positive
        )
    }
}
