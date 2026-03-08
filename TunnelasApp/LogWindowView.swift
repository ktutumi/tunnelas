import SwiftUI
import TunnelasCore

struct LogWindowView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedRuleKey) {
                ForEach(model.snapshot.groups) { group in
                    Section(group.title) {
                        ForEach(group.rules) { rule in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.title)
                                Text(rule.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(rule.id)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 280)
            .onChange(of: model.selectedRuleKey) { _ in
                Task { await model.refreshLogs() }
            }
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(selectedTitle)
                        .font(.headline)
                    Spacer()
                    Button("Open Log File") {
                        model.openLogFile()
                    }
                }

                if let selectedRule = selectedRule,
                   let error = selectedRule.state.error {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Latest Error")
                            .font(.subheadline.weight(.semibold))
                        Text(error.message)
                            .foregroundStyle(.red)
                        if let suggestion = error.suggestion {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(model.currentLogs) { entry in
                            Text("[\(entry.timestamp.formatted(date: .omitted, time: .standard))] \(entry.text)")
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }

    private var selectedRule: RuleSnapshot? {
        model.snapshot.groups
            .flatMap(\.rules)
            .first(where: { $0.id == model.selectedRuleKey })
    }

    private var selectedTitle: String {
        selectedRule?.title ?? "Select a rule"
    }
}
