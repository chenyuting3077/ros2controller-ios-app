import Foundation
import Observation

enum ConnectionState: Equatable {
    case disconnected
    case connecting(attempt: Int)
    case connected
    case error(String)

    var displayText: String {
        switch self {
        case .disconnected:          return "Disconnected"
        case .connecting(let n):     return n > 1 ? "Reconnecting… (attempt \(n))" : "Connecting…"
        case .connected:             return "Connected"
        case .error(let msg):        return "Error: \(msg)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isConnecting: Bool {
        if case .connecting = self { return true }
        return false
    }
}

@Observable
class ROSBridgeManager: NSObject {
    var connectionState: ConnectionState = .disconnected
    var allTopics: [String] = []
    var topicStats: [String: TopicStats] = [:]

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var currentURL: String = ""
    private var userDidDisconnect = false
    private var reconnectDelay: Double = 2.0
    private var reconnectAttempt: Int = 0
    private var statsTimer: Timer?
    private var subscribedTopics: Set<String> = []
    private var advertisedTopics: Set<String> = []

    // MARK: - Public interface

    func connect(to url: String) {
        userDidDisconnect = false
        currentURL = url
        reconnectAttempt = 0
        reconnectDelay = 2.0
        performConnect()
    }

    func disconnect() {
        userDidDisconnect = true
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        connectionState = .disconnected
        stopStatsTimer()
        subscribedTopics.removeAll()
        advertisedTopics.removeAll()
        allTopics.removeAll()
    }

    func publishTwist(linearX: Double, linearY: Double, angularZ: Double, topic: String) {
        guard connectionState.isConnected else { return }
        let msg: [String: Any] = [
            "op": "publish",
            "topic": topic,
            "msg": [
                "linear": ["x": linearX, "y": linearY, "z": 0.0],
                "angular": ["x": 0.0, "y": 0.0, "z": angularZ]
            ]
        ]
        send(msg)
    }

    func fetchTopicList() {
        let msg: [String: Any] = [
            "op": "call_service",
            "id": "get-topics",
            "service": "/rosapi/topics",
            "args": []
        ]
        send(msg)
    }

    func subscribeForStats(topic: String) {
        guard !subscribedTopics.contains(topic) else { return }
        subscribedTopics.insert(topic)
        if topicStats[topic] == nil {
            topicStats[topic] = TopicStats()
        }
        let msg: [String: Any] = [
            "op": "subscribe",
            "id": "monitor-\(topic)",
            "topic": topic,
            "throttle_rate": 100
        ]
        send(msg)
    }

    func unsubscribe(topic: String) {
        subscribedTopics.remove(topic)
        let msg: [String: Any] = [
            "op": "unsubscribe",
            "topic": topic
        ]
        send(msg)
    }

    // MARK: - Private helpers

    private func performConnect() {
        guard let url = URL(string: currentURL) else {
            connectionState = .error("Invalid URL: \(currentURL)")
            return
        }
        connectionState = .connecting(attempt: max(1, reconnectAttempt))
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        urlSession = session
        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        receiveNext(from: task)
    }

    private func advertise(topic: String, type: String) {
        guard !advertisedTopics.contains(topic) else { return }
        advertisedTopics.insert(topic)
        let msg: [String: Any] = [
            "op": "advertise",
            "topic": topic,
            "type": type
        ]
        send(msg)
    }

    private func send(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { _ in }
    }

    private func receiveNext(from task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.webSocketTask === task else { return }
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.receiveNext(from: task)
                case .failure(let error):
                    if !self.userDidDisconnect {
                        self.connectionState = .error(error.localizedDescription)
                        self.scheduleReconnect()
                    }
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        var data: Data?
        switch message {
        case .string(let text):
            data = text.data(using: .utf8)
        case .data(let d):
            data = d
        @unknown default:
            return
        }
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let op = json["op"] as? String else { return }

        let messageSize = data.count

        switch op {
        case "service_response":
            if let id = json["id"] as? String, id == "get-topics",
               let values = json["values"] as? [String: Any],
               let topics = values["topics"] as? [String] {
                allTopics = topics.sorted()
            }
        case "publish":
            if let topic = json["topic"] as? String {
                topicStats[topic, default: TopicStats()].update(with: messageSize)
            }
        default:
            break
        }
    }

    // MARK: - Stats timer

    private func startStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            for key in self.topicStats.keys {
                self.topicStats[key]?.tick(elapsed: 1.0)
            }
        }
    }

    private func stopStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    // MARK: - Reconnect

    private func scheduleReconnect() {
        guard !userDidDisconnect else {
            connectionState = .disconnected
            return
        }
        stopStatsTimer()
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 30.0)
        reconnectAttempt += 1
        let attempt = reconnectAttempt
        connectionState = .connecting(attempt: attempt)
        Task { @MainActor [weak self] in
            guard let self, !self.userDidDisconnect else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !self.userDidDisconnect else { return }
            self.performConnect()
        }
    }

    private func onConnected() {
        connectionState = .connected
        reconnectAttempt = 0
        reconnectDelay = 2.0
        advertisedTopics.removeAll()
        advertise(topic: "/cmd_vel", type: "geometry_msgs/Twist")
        startStatsTimer()
        fetchTopicList()
    }
}

// MARK: - URLSessionWebSocketDelegate

extension ROSBridgeManager: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.webSocketTask === webSocketTask else { return }
            self.onConnected()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.webSocketTask === webSocketTask else { return }
            self.stopStatsTimer()
            self.scheduleReconnect()
        }
    }
}
