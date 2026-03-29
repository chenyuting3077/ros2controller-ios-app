import SwiftUI

struct ConnectionView: View {
    @Environment(ROSBridgeManager.self) private var ros
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var s = settings
        NavigationStack {
            Form {
                Section("Server") {
                    LabeledContent("Host / IP") {
                        TextField("192.168.1.100", text: $s.host)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    LabeledContent("Port") {
                        TextField("9090", value: $s.port, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                }

                Section("Status") {
                    HStack {
                        statusDot
                        Text(ros.connectionState.displayText)
                            .foregroundStyle(statusColor)
                    }
                    connectButton
                }
            }
            .navigationTitle("Connect")
        }
    }

    // MARK: - Sub-views

    private var connectButton: some View {
        Button {
            if ros.connectionState.isConnected || ros.connectionState.isConnecting {
                ros.disconnect()
            } else {
                let url = "ws://\(settings.host):\(settings.port)"
                ros.connect(to: url)
            }
        } label: {
            if ros.connectionState.isConnected || ros.connectionState.isConnecting {
                Text("Disconnect")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.red)
            } else {
                Text("Connect")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }

    private var statusColor: Color {
        switch ros.connectionState {
        case .connected:     return .green
        case .connecting:    return .yellow
        case .disconnected:  return .gray
        case .error:         return .red
        }
    }
}
