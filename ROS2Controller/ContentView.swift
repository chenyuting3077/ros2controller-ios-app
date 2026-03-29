import SwiftUI

struct ContentView: View {
    @Environment(ROSBridgeManager.self) private var ros
    @Environment(AppSettings.self) private var settings

    var body: some View {
        TabView {
            ConnectionView()
                .tabItem { Label("Connect", systemImage: "wifi") }

            JoystickView()
                .tabItem { Label("Control", systemImage: "gamecontroller") }

            TopicMonitorView()
                .tabItem { Label("Topics", systemImage: "chart.bar") }
        }
    }
}

#Preview {
    ContentView()
        .environment(ROSBridgeManager())
        .environment(AppSettings())
}
