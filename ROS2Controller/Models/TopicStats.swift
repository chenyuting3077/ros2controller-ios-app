import Foundation

struct TopicStats {
    var messageCount: Int = 0
    var byteCount: Int = 0
    var hz: Double = 0
    var bw: Double = 0  // bytes per second

    mutating func update(with messageSize: Int) {
        messageCount += 1
        byteCount += messageSize
    }

    mutating func tick(elapsed: Double) {
        hz = elapsed > 0 ? Double(messageCount) / elapsed : 0
        bw = elapsed > 0 ? Double(byteCount) / elapsed : 0
        messageCount = 0
        byteCount = 0
    }

    var bwFormatted: String {
        if bw >= 1_000_000 {
            return String(format: "%.1f MB/s", bw / 1_000_000)
        } else if bw >= 1024 {
            return String(format: "%.1f KB/s", bw / 1024)
        } else {
            return String(format: "%.0f B/s", bw)
        }
    }
}
