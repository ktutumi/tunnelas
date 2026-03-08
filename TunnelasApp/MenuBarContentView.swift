import SwiftUI
import TunnelasCore

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Tunnelas")
        Text(model.snapshot.menuSummary.statusLine)

        if let error = model.configurationError {
            Divider()
            Label("Configuration Error", systemImage: "exclamationmark.triangle.fill")
            Text(error)
            Button("Reload Configuration") {
                model.reloadConfiguration()
            }
            Button("Settings…") {
                openSettings()
            }
        }

        if !model.snapshot.groups.isEmpty {
            Divider()
            Section("Groups") {
                ForEach(model.snapshot.groups) { group in
                    GroupMenu(
                        group: group,
                        onStartGroup: { model.startGroup(group.id) },
                        onStopGroup: { model.stopGroup(group.id) },
                        onStartRule: model.startRule,
                        onStopRule: model.stopRule,
                        onOpenLogs: openLogs,
                        onOpenRuleLogs: openRuleLogs
                    )
                }
            }
        }

        Divider()

        Button("Reload Configuration") {
            model.reloadConfiguration()
        }
        Button("Open Config Folder") {
            model.openConfigFolder()
        }
        Button("Open Logs") {
            openLogs()
        }
        Button("Settings…") {
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func openLogs() {
        openWindow(id: "logs")
    }

    private func openRuleLogs(_ key: RuleKey) {
        model.selectRuleForLogs(key)
        openLogs()
    }
}

private struct GroupMenu: View {
    let group: GroupSnapshot
    let onStartGroup: () -> Void
    let onStopGroup: () -> Void
    let onStartRule: (RuleKey) -> Void
    let onStopRule: (RuleKey) -> Void
    let onOpenLogs: () -> Void
    let onOpenRuleLogs: (RuleKey) -> Void

    var body: some View {
        Menu {
            Text(group.menuSummaryLine)

            if !group.hasEnabledRules {
                Text("All rules are disabled in config")
            }

            Divider()

            Button("Start All", action: onStartGroup)
                .disabled(!group.canStartAnyRule)
            Button("Stop All", action: onStopGroup)
                .disabled(!group.canStopAnyRule)

            Divider()

            ForEach(group.rules) { rule in
                RuleMenu(
                    rule: rule,
                    onStartRule: onStartRule,
                    onStopRule: onStopRule,
                    onOpenLogs: onOpenLogs,
                    onOpenRuleLogs: onOpenRuleLogs
                )
            }
        } label: {
            Text(group.menuDisplayTitle)
                .accessibilityLabel("\(group.title), \(group.menuStatusAccessibilityLabel)")
        }
    }
}

private struct RuleMenu: View {
    let rule: RuleSnapshot
    let onStartRule: (RuleKey) -> Void
    let onStopRule: (RuleKey) -> Void
    let onOpenLogs: () -> Void
    let onOpenRuleLogs: (RuleKey) -> Void

    var body: some View {
        Menu {
            Text(rule.subtitle)
            Text("Status: \(rule.statusText)")

            if !rule.isEnabled {
                Text("Disabled in config")
            }

            if let error = rule.state.error {
                Divider()
                Text("Error: \(error.message)")
                if let suggestion = error.suggestion {
                    Text("Suggestion: \(suggestion)")
                }
            }

            if let logLine = rule.lastLogLine {
                Divider()
                Text("Latest log")
                Text(logLine)
            }

            Divider()

            if rule.canStartFromMenu {
                Button("Start") {
                    onStartRule(rule.id)
                }
            }

            if rule.canStopFromMenu {
                Button("Stop") {
                    onStopRule(rule.id)
                }
            }

            Button("Open Rule Logs") {
                onOpenRuleLogs(rule.id)
            }
            Button("Open Logs Window") {
                onOpenLogs()
            }
        } label: {
            Text(rule.menuDisplayTitle)
                .accessibilityLabel("\(rule.title), \(rule.menuStatusAccessibilityLabel)")
        }
    }
}
