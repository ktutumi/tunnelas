import SwiftUI
import TunnelasCore

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let error = model.configurationError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.snapshot.groups) { group in
                        GroupSectionView(
                            group: group,
                            onStartGroup: { model.startGroup(group.id) },
                            onStopGroup: { model.stopGroup(group.id) },
                            onStartRule: model.startRule,
                            onStopRule: model.stopRule
                        )
                    }
                }
            }
            .frame(minWidth: 420, minHeight: 320)

            Divider()

            HStack {
                Button("Settings") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                Spacer()
                Button("Open Logs") { openWindow(id: "logs") }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tunnelas")
                    .font(.headline)
                Text(model.configurationURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Reload") {
                model.reloadConfiguration()
            }
            Button("Config Folder") {
                model.openConfigFolder()
            }
        }
    }
}

private struct GroupSectionView: View {
    let group: GroupSnapshot
    let onStartGroup: () -> Void
    let onStopGroup: () -> Void
    let onStartRule: (RuleKey) -> Void
    let onStopRule: (RuleKey) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.subheadline.weight(.semibold))
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Start All", action: onStartGroup)
                    .disabled(group.rules.allSatisfy { !$0.isEnabled })
                Button("Stop All", action: onStopGroup)
            }

            ForEach(group.rules) { rule in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: iconName(for: rule.state.status))
                        .foregroundStyle(color(for: rule.state.status))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.title)
                            .font(.body)
                        Text(rule.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let logLine = rule.lastLogLine {
                            Text(logLine)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let error = rule.state.error {
                            Text(error.message)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    Button("Start") { onStartRule(rule.id) }
                        .disabled(!rule.isEnabled)
                    Button("Stop") { onStopRule(rule.id) }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var summary: String {
        let running = group.rules.filter { $0.state.status == .running }.count
        return "\(running)/\(group.rules.count) running"
    }

    private func iconName(for status: RuleStatus) -> String {
        switch status {
        case .stopped:
            return "pause.circle"
        case .starting:
            return "clock"
        case .running:
            return "play.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private func color(for status: RuleStatus) -> Color {
        switch status {
        case .stopped:
            return .secondary
        case .starting:
            return .orange
        case .running:
            return .green
        case .error:
            return .red
        }
    }
}
