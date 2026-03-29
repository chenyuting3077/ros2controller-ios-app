import Foundation
import Observation

@Observable
class AppSettings {
    var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "host") }
    }
    var port: Int {
        didSet { UserDefaults.standard.set(port, forKey: "port") }
    }
    var cmdVelTopic: String {
        didSet { UserDefaults.standard.set(cmdVelTopic, forKey: "cmdVelTopic") }
    }
    var maxLinearSpeed: Double {
        didSet { UserDefaults.standard.set(maxLinearSpeed, forKey: "maxLinearSpeed") }
    }
    var maxAngularSpeed: Double {
        didSet { UserDefaults.standard.set(maxAngularSpeed, forKey: "maxAngularSpeed") }
    }
    var publishHz: Double {
        didSet { UserDefaults.standard.set(publishHz, forKey: "publishHz") }
    }
    var watchedTopics: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(watchedTopics), forKey: "watchedTopics")
        }
    }

    init() {
        let d = UserDefaults.standard
        host = d.string(forKey: "host") ?? "192.168.1.100"
        let savedPort = d.integer(forKey: "port")
        port = savedPort == 0 ? 9090 : savedPort
        cmdVelTopic = d.string(forKey: "cmdVelTopic") ?? "/cmd_vel"
        let lin = d.double(forKey: "maxLinearSpeed")
        maxLinearSpeed = lin == 0 ? 1.0 : lin
        let ang = d.double(forKey: "maxAngularSpeed")
        maxAngularSpeed = ang == 0 ? 1.5 : ang
        let hz = d.double(forKey: "publishHz")
        publishHz = hz == 0 ? 10.0 : hz
        if let arr = d.array(forKey: "watchedTopics") as? [String] {
            watchedTopics = Set(arr)
        } else {
            watchedTopics = []
        }
    }
}
