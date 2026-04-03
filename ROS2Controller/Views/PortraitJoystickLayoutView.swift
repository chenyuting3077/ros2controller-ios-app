import SwiftUI

struct PortraitJoystickLayoutView: View {
    let joystickSize: CGFloat
    @Binding var leftJoystick: CGPoint
    @Binding var rightJoystick: CGPoint

    var body: some View {
        HStack(alignment: .bottom) {
            JoystickPadView(label: "linear", size: joystickSize) { value in
                leftJoystick = value
            }

            Spacer(minLength: 24)

            JoystickPadView(label: "yaw", size: joystickSize) { value in
                rightJoystick = value
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.leading, 50)
        .padding(.trailing, 50)
        .padding(.bottom, 50)
    }
}
