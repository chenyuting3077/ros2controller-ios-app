import SwiftUI

struct JoystickView: View {
    @Environment(ROSBridgeManager.self) private var ros
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase

    @State private var leftJoystick: CGPoint = .zero    // x=linearY, y=linearX
    @State private var rightJoystick: CGPoint = .zero   // x=angularZ
    @State private var showControlSettings = false
    @State private var publishTimer: Timer?

    private var linearX: Double { leftJoystick.y * settings.maxLinearSpeed }
    private var linearY: Double { leftJoystick.x * settings.maxLinearSpeed }
    private var angularZ: Double { rightJoystick.x * settings.maxAngularSpeed }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if !ros.connectionState.isConnected {
                    VStack {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(ros.connectionState.displayText)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)
                    .opacity(0.6)
                }

                VStack(spacing: 0) {
                    // Status bar
                    HStack {
                        statusIndicator
                        Text(settings.cmdVelTopic)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "x: %.2f  y: %.2f  yaw: %.2f", linearX, linearY, angularZ))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Button { showControlSettings = true } label: {
                            Image(systemName: "gearshape")
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    Spacer()

                    // Joystick row
                    HStack {
                        Spacer()
                        JoystickPadView(label: "linear", size: joystickSize(geo)) { v in
                            leftJoystick = v
                        }
                        Spacer()
                        JoystickPadView(label: "yaw", size: joystickSize(geo)) { v in
                            rightJoystick = v
                        }
                        Spacer()
                    }

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showControlSettings) {
            ControlSettingsSheet()
                .presentationDetents([.medium])
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .onChange(of: settings.publishHz) { _, _ in
            startTimer()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                sendZero()
                stopTimer()
            } else if phase == .active {
                startTimer()
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        let interval = 1.0 / max(1, settings.publishHz)
        publishTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            guard ros.connectionState.isConnected else { return }
            ros.publishTwist(
                linearX: linearX,
                linearY: linearY,
                angularZ: angularZ,
                topic: settings.cmdVelTopic
            )
        }
    }

    private func stopTimer() {
        publishTimer?.invalidate()
        publishTimer = nil
    }

    private func sendZero() {
        guard ros.connectionState.isConnected else { return }
        ros.publishTwist(linearX: 0, linearY: 0, angularZ: 0, topic: settings.cmdVelTopic)
    }

    // MARK: - Helpers

    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(ros.connectionState.displayText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch ros.connectionState {
        case .connected:         return .green
        case .connecting:        return .yellow
        case .disconnected:      return .gray
        case .error:             return .red
        }
    }

    private func joystickSize(_ geo: GeometryProxy) -> CGFloat {
        min(geo.size.height * 0.55, geo.size.width * 0.3)
    }
}

// MARK: - Control Settings Sheet

struct ControlSettingsSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var s = settings
        NavigationStack {
            Form {
                Section("Topic") {
                    TextField("cmd_vel Topic", text: $s.cmdVelTopic)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section("Speed Limits") {
                    LabeledContent("Max Linear: \(settings.maxLinearSpeed, specifier: "%.1f") m/s") {
                        Slider(value: $s.maxLinearSpeed, in: 0.1...3.0)
                    }
                    LabeledContent("Max Angular: \(settings.maxAngularSpeed, specifier: "%.1f") rad/s") {
                        Slider(value: $s.maxAngularSpeed, in: 0.1...5.0)
                    }
                }
                Section("Publish Rate") {
                    Picker("Rate", selection: $s.publishHz) {
                        Text("5 Hz").tag(5.0)
                        Text("10 Hz").tag(10.0)
                        Text("20 Hz").tag(20.0)
                        Text("50 Hz").tag(50.0)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Control Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
