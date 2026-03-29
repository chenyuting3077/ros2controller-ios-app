import SwiftUI

@main
struct ROS2ControllerApp: App {
    @State private var rosManager = ROSBridgeManager()
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(rosManager)
                .environment(settings)
        }
    }
}
