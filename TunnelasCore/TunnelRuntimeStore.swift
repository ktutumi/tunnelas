import Foundation

public actor TunnelRuntimeStore {
    private let commandBuilder: any CommandBuilding
    private let processRunner: any ProcessRunning
    private let logWriter: any LogWriting
    private let logLimit: Int

    private var configurationIndex = ConfigurationIndex(configuration: AppConfiguration(version: 1, ssh: [], kubernetes: []))
    private var states: [RuleKey: RuleRuntimeState] = [:]
    private var logs: [RuleKey: [LogEntry]] = [:]
    private var sessions: [RuleKey: ManagedProcessSession] = [:]
    private var eventTasks: [RuleKey: Task<Void, Never>] = [:]
    private var stoppingRules = Set<RuleKey>()
    private var preSleepRunningRules = Set<RuleKey>()
    private var continuations: [UUID: AsyncStream<RuntimeSnapshot>.Continuation] = [:]

    public init(
        commandBuilder: any CommandBuilding,
        processRunner: any ProcessRunning,
        logWriter: any LogWriting,
        logLimit: Int = 200
    ) {
        self.commandBuilder = commandBuilder
        self.processRunner = processRunner
        self.logWriter = logWriter
        self.logLimit = logLimit
    }

    public func updates() -> AsyncStream<RuntimeSnapshot> {
        let identifier = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(identifier) }
            }
            continuations[identifier] = continuation
            continuation.yield(makeSnapshot())
        }
    }

    public func snapshot() -> RuntimeSnapshot {
        makeSnapshot()
    }

    public func applyConfiguration(_ configuration: AppConfiguration) async {
        let previousIndex = configurationIndex
        let newIndex = ConfigurationIndex(configuration: configuration)
        let removedKeys = Set(previousIndex.rulesByKey.keys).subtracting(newIndex.rulesByKey.keys)
        let changedKeys = newIndex.rulesByKey.compactMap { key, definition in
            previousIndex.rulesByKey[key] == definition ? nil : key
        }

        for key in removedKeys {
            await stopRule(key)
            states.removeValue(forKey: key)
            logs.removeValue(forKey: key)
        }

        configurationIndex = newIndex

        for (key, _) in newIndex.rulesByKey where states[key] == nil {
            states[key] = .stopped()
        }

        for key in changedKeys where sessions[key] != nil {
            await restartRule(key)
        }

        await appendSystemLog("configuration applied")
        emitSnapshot()
    }

    public func startEnabledRules() async {
        for definition in configurationIndex.rulesByKey.values.sorted(by: { $0.key.ruleID < $1.key.ruleID }) where definition.isEnabled {
            await startRule(definition.key)
        }
    }

    public func startGroup(_ key: GroupKey) async {
        guard let group = configurationIndex.groups.first(where: { $0.key == key }) else {
            return
        }
        for ruleKey in group.ruleKeys {
            await startRule(ruleKey)
        }
    }

    public func stopGroup(_ key: GroupKey) async {
        guard let group = configurationIndex.groups.first(where: { $0.key == key }) else {
            return
        }
        for ruleKey in group.ruleKeys {
            await stopRule(ruleKey)
        }
    }

    public func startRule(_ key: RuleKey) async {
        guard let definition = configurationIndex.rulesByKey[key] else { return }
        guard definition.isEnabled else {
            states[key] = .failed(.init(message: "Rule is disabled", suggestion: "Enable the rule in config.json"))
            emitSnapshot()
            return
        }
        guard sessions[key] == nil else { return }

        states[key] = .starting()
        emitSnapshot()

        do {
            let command = try commandBuilder.makeCommand(for: definition)
            let session = try processRunner.start(command: command)
            sessions[key] = session
            states[key] = .running(pid: session.processIdentifier)
            await appendLog(text: "[command] \(command.shellDescription)", for: key)
            await appendSystemLog("started \(describe(key))")
            let task = Task { [events = session.events] in
                for await event in events {
                    await self.handle(event: event, for: key)
                }
            }
            eventTasks[key] = task
            emitSnapshot()
        } catch {
            let summary = summarize(error: error)
            states[key] = .failed(summary)
            await appendLog(text: "[error] \(summary.message)", for: key)
            await appendSystemLog("failed to start \(describe(key)): \(summary.message)")
            emitSnapshot()
        }
    }

    public func stopRule(_ key: RuleKey) async {
        guard let session = sessions[key] else {
            states[key] = .stopped()
            emitSnapshot()
            return
        }
        stoppingRules.insert(key)
        session.stop()
        await appendSystemLog("stopping \(describe(key))")
    }

    public func beginSleep() async {
        preSleepRunningRules = Set(sessions.keys)
        await appendSystemLog("system will sleep")
    }

    public func handleWake() async {
        await appendSystemLog("system did wake")
        let candidates = preSleepRunningRules.filter { key in
            guard let definition = configurationIndex.rulesByKey[key] else { return false }
            return definition.isEnabled
        }
        preSleepRunningRules.removeAll()

        for key in candidates {
            await restartRule(key)
        }
    }

    public func shutdown() async {
        for key in Array(sessions.keys) {
            await stopRule(key)
        }
    }

    public func logEntries(for key: RuleKey, limit: Int = 200) -> [LogEntry] {
        Array((logs[key] ?? []).suffix(limit))
    }

    private func restartRule(_ key: RuleKey) async {
        if sessions[key] != nil {
            stoppingRules.insert(key)
            sessions[key]?.stop()
            await appendSystemLog("restarting \(describe(key))")
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        await startRule(key)
    }

    private func handle(event: ProcessEvent, for key: RuleKey) async {
        switch event {
        case let .stdout(output):
            await appendLog(text: output, for: key)
        case let .stderr(output):
            await appendLog(text: output, for: key)
        case let .terminated(exitCode):
            sessions.removeValue(forKey: key)
            eventTasks[key]?.cancel()
            eventTasks.removeValue(forKey: key)

            let wasStopping = stoppingRules.remove(key) != nil
            if wasStopping || exitCode == 0 {
                states[key] = .stopped()
            } else {
                let summary = RuleErrorSummary(
                    message: "Process exited with code \(exitCode ?? -1)",
                    suggestion: "Open the log window and confirm stderr output"
                )
                states[key] = .failed(summary)
                await appendLog(text: "[terminated] exit code \(exitCode ?? -1)", for: key)
                await appendSystemLog("process exited unexpectedly \(describe(key)) code=\(exitCode ?? -1)")
            }

            emitSnapshot()
        }
    }

    private func appendLog(text: String, for key: RuleKey) async {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }

        if lines.isEmpty { return }

        var current = logs[key] ?? []
        for line in lines {
            current.append(LogEntry(text: line))
            if current.count > logLimit {
                current.removeFirst(current.count - logLimit)
            }
            await logWriter.write(line: "[\(describe(key))] \(line)")
        }
        logs[key] = current
        emitSnapshot()
    }

    private func appendSystemLog(_ line: String) async {
        await logWriter.write(line: "[system] \(line)")
    }

    private func emitSnapshot() {
        let snapshot = makeSnapshot()
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func makeSnapshot() -> RuntimeSnapshot {
        let groups = configurationIndex.groups.map { group in
            let rules = group.ruleKeys.compactMap { key -> RuleSnapshot? in
                guard let definition = configurationIndex.rulesByKey[key] else { return nil }
                return RuleSnapshot(
                    id: key,
                    title: definition.ruleTitle,
                    subtitle: definition.ruleSubtitle,
                    isEnabled: definition.isEnabled,
                    state: states[key] ?? .stopped(),
                    lastLogLine: logs[key]?.last?.text
                )
            }
            return GroupSnapshot(id: group.key, title: group.title, isEnabled: group.isEnabled, rules: rules)
        }
        return RuntimeSnapshot(groups: groups)
    }

    private func describe(_ key: RuleKey) -> String {
        "\(key.kind.rawValue):\(key.groupID):\(key.ruleID)"
    }

    private func summarize(error: Error) -> RuleErrorSummary {
        let message = String(describing: error)
        if message.contains("No such file") || message.contains("not found") {
            return RuleErrorSummary(message: "Required command is not installed", suggestion: "Install ssh or kubectl and retry")
        }
        return RuleErrorSummary(message: message, suggestion: "Check the configuration and command availability")
    }

    private func removeContinuation(_ identifier: UUID) {
        continuations.removeValue(forKey: identifier)
    }
}

