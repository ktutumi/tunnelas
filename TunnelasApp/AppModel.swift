import AppKit
import Foundation
import SwiftUI
import TunnelasCore
import TunnelasInfra

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: RuntimeSnapshot = .empty
    @Published var selectedRuleKey: RuleKey?
    @Published var currentLogs: [LogEntry] = []
    @Published var configurationError: String?

    let configurationURL: URL
    let logFileURL: URL

    private let repository: any ConfigurationRepository
    private let runtime: TunnelRuntimeStore
    private let sleepWakeObserver: SystemSleepWakeObserver
    private var streamTask: Task<Void, Never>?
    private var terminationObserver: NSObjectProtocol?

    init(
        repository: any ConfigurationRepository,
        runtime: TunnelRuntimeStore,
        sleepWakeObserver: SystemSleepWakeObserver,
        logFileURL: URL
    ) {
        self.repository = repository
        self.runtime = runtime
        self.sleepWakeObserver = sleepWakeObserver
        self.configurationURL = repository.configurationURL
        self.logFileURL = logFileURL

        self.sleepWakeObserver.onSleep = { [weak self] in
            guard let self else { return }
            Task { await self.runtime.beginSleep() }
        }
        self.sleepWakeObserver.onWake = { [weak self] in
            guard let self else { return }
            Task { await self.runtime.handleWake() }
        }
        self.sleepWakeObserver.start()
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.runtime.shutdown() }
        }

        streamTask = Task { [weak self] in
            guard let self else { return }
            let updates = await runtime.updates()
            for await snapshot in updates {
                await MainActor.run {
                    self.snapshot = snapshot
                    if self.selectedRuleKey == nil {
                        self.selectedRuleKey = snapshot.groups.first?.rules.first?.id
                    }
                }
                await self.refreshLogs()
            }
        }

        Task { await loadInitialConfiguration() }
    }

    func loadInitialConfiguration() async {
        do {
            let configuration = try repository.load()
            configurationError = nil
            await runtime.applyConfiguration(configuration)
            await runtime.startEnabledRules()
        } catch {
            configurationError = error.localizedDescription
        }
    }

    func reloadConfiguration() {
        Task {
            do {
                let configuration = try repository.load()
                configurationError = nil
                await runtime.applyConfiguration(configuration)
            } catch {
                await MainActor.run {
                    self.configurationError = error.localizedDescription
                }
            }
        }
    }

    func startGroup(_ key: GroupKey) {
        Task { await runtime.startGroup(key) }
    }

    func stopGroup(_ key: GroupKey) {
        Task { await runtime.stopGroup(key) }
    }

    func startRule(_ key: RuleKey) {
        Task { await runtime.startRule(key) }
    }

    func stopRule(_ key: RuleKey) {
        Task { await runtime.stopRule(key) }
    }

    func refreshLogs() async {
        guard let selectedRuleKey else {
            await MainActor.run {
                self.currentLogs = []
            }
            return
        }

        let entries = await runtime.logEntries(for: selectedRuleKey)
        await MainActor.run {
            self.currentLogs = entries
        }
    }

    func openConfigFolder() {
        NSWorkspace.shared.open(configurationURL.deletingLastPathComponent())
    }

    func openLogFile() {
        NSWorkspace.shared.open(logFileURL)
    }
    static func bootstrap() -> AppModel {
        let loader = FileConfigurationLoader()
        let repository = DefaultConfigurationRepository(loader: loader)
        let logSink = FileLogSink()
        let runtime = TunnelRuntimeStore(
            commandBuilder: SystemCommandBuilder(),
            processRunner: SystemProcessRunner(),
            logWriter: logSink
        )
        return AppModel(
            repository: repository,
            runtime: runtime,
            sleepWakeObserver: SystemSleepWakeObserver(),
            logFileURL: logSink.logFileURL
        )
    }
}
