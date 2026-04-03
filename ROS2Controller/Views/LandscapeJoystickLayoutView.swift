import SwiftUI

struct LandscapeJoystickLayoutView: View {
    let joystickSize: CGFloat
    @Binding var leftJoystick: CGPoint
    @Binding var rightJoystick: CGPoint

    var body: some View {
        HStack(alignment: .bottom) {
            JoystickPadView(label: "linear", size: joystickSize) { value in
                leftJoystick = value
            }

            Spacer(minLength: 20)

            JoystickPadView(label: "yaw", size: joystickSize) { value in
                rightJoystick = value
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }
}
