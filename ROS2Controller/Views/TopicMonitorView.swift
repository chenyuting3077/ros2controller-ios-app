import SwiftUI

struct TopicMonitorView: View {
    @Environment(ROSBridgeManager.self) private var ros
    @Environment(AppSettings.self) private var settings

    @State private var isEditing = false

    private var displayedTopics: [String] {
        if isEditing {
            return ros.allTopics
        } else {
            return ros.allTopics.filter { settings.watchedTopics.contains($0) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !ros.connectionState.isConnected {
                    ContentUnavailableView(
                        "Not Connected",
                        systemImage: "wifi.slash",
                        description: Text("Connect to a rosbridge server to monitor topics.")
                    )
                } else if ros.allTopics.isEmpty {
                    ContentUnavailableView(
                        "No Topics",
                        systemImage: "chart.bar",
                        description: Text("Pull down to refresh.")
                    )
                } else {
                    List(displayedTopics, id: \.self) { topic in
                        topicRow(topic)
                    }
                    .refreshable {
                        ros.fetchTopicList()
                    }
                }
            }
            .navigationTitle("Topics")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        ros.fetchTopicList()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!ros.connectionState.isConnected)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                    }
                    .disabled(!ros.connectionState.isConnected)
                }
            }
        }
        .onChange(of: ros.allTopics) { _, topics in
            guard !topics.isEmpty else { return }
            let newTopics = Set(topics)
            if settings.watchedTopics.isEmpty {
                // First connect: subscribe all by default
                for t in topics { ros.subscribeForStats(topic: t) }
                settings.watchedTopics = newTopics
            } else {
                // Re-subscribe only the previously watched topics that still exist
                for t in settings.watchedTopics.intersection(newTopics) {
                    ros.subscribeForStats(topic: t)
                }
            }
        }
    }

    @ViewBuilder
    private func topicRow(_ topic: String) -> some View {
        let stats = ros.topicStats[topic]
        let isWatched = settings.watchedTopics.contains(topic)

        HStack {
            if isEditing {
                Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isWatched ? Color.accentColor : Color.secondary)
                    .onTapGesture { toggleWatch(topic) }
            }
            Text(topic)
                .font(.system(.subheadline, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            if let s = stats {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f Hz", s.hz))
                        .font(.caption.monospaced())
                        .foregroundStyle(hzColor(s.hz))
                    Text(s.bwFormatted)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            } else if isWatched {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing { toggleWatch(topic) }
        }
    }

    private func toggleWatch(_ topic: String) {
        if settings.watchedTopics.contains(topic) {
            settings.watchedTopics.remove(topic)
            ros.unsubscribe(topic: topic)
        } else {
            settings.watchedTopics.insert(topic)
            ros.subscribeForStats(topic: topic)
        }
    }

    private func hzColor(_ hz: Double) -> Color {
        if hz > 0.1    { return .green }
        if hz > 0      { return .yellow }
        return .secondary
    }
}
