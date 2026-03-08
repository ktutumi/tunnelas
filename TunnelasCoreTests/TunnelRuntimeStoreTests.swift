import Foundation
import Testing
@testable import TunnelasCore

struct TunnelRuntimeStoreTests {
    @Test
    func runtimeMenuSummaryCountsStatuses() {
        let snapshot = RuntimeSnapshot(groups: [
            GroupSnapshot(
                id: GroupKey(kind: .ssh, id: "bastion"),
                title: "Bastion",
                isEnabled: true,
                rules: [
                    menuRule(id: "db", status: .running),
                    menuRule(id: "api", status: .starting),
                    menuRule(id: "metrics", status: .error)
                ]
            ),
            GroupSnapshot(
                id: GroupKey(kind: .kubernetes, id: "dev"),
                title: "Dev",
                isEnabled: true,
                rules: [
                    menuRule(kind: .kubernetes, groupID: "dev", id: "web", status: .stopped)
                ]
            )
        ])

        let summary = snapshot.menuSummary

        #expect(summary.totalRules == 4)
        #expect(summary.runningRules == 1)
        #expect(summary.startingRules == 1)
        #expect(summary.errorRules == 1)
        #expect(summary.menuBarIconName == "exclamationmark.triangle.fill")
    }

    @Test
    func groupSummaryExposesMenuState() {
        let group = GroupSnapshot(
            id: GroupKey(kind: .ssh, id: "bastion"),
            title: "Bastion",
            isEnabled: true,
            rules: [
                menuRule(id: "db", status: .running),
                menuRule(id: "api", status: .starting),
                menuRule(id: "metrics", status: .error),
                menuRule(id: "disabled", status: .stopped, isEnabled: false)
            ]
        )

        #expect(group.runningRuleCount == 1)
        #expect(group.startingRuleCount == 1)
        #expect(group.errorRuleCount == 1)
        #expect(group.canStartAnyRule == true)
        #expect(group.canStopAnyRule == true)
        #expect(group.menuSummaryLine == "1/4 running  1 starting  1 errors")
        #expect(group.menuSymbolName == "exclamationmark.triangle.fill")
        #expect(group.menuDisplayTitle == "Bastion [Error]")
        #expect(group.menuStatusAccessibilityLabel == "Status: Error")
    }

    @Test
    func ruleMenuActionsReflectStateAndEnablement() {
        let stopped = menuRule(id: "db", status: .stopped)
        let running = menuRule(id: "api", status: .running)
        let starting = menuRule(id: "metrics", status: .starting)
        let errored = menuRule(id: "job", status: .error)
        let disabled = menuRule(id: "disabled", status: .stopped, isEnabled: false)

        #expect(stopped.canStartFromMenu == true)
        #expect(stopped.canStopFromMenu == false)
        #expect(running.canStartFromMenu == false)
        #expect(running.canStopFromMenu == true)
        #expect(starting.canStartFromMenu == false)
        #expect(starting.canStopFromMenu == true)
        #expect(errored.canStartFromMenu == true)
        #expect(errored.canStopFromMenu == false)
        #expect(disabled.canStartFromMenu == false)
        #expect(disabled.canStopFromMenu == false)
    }

    @Test
    func ruleMenuStatusDisplayExposesAllStatuses() {
        let stopped = menuRule(id: "db", status: .stopped)
        let running = menuRule(id: "api", status: .running)
        let starting = menuRule(id: "metrics", status: .starting)
        let errored = menuRule(id: "job", status: .error)

        #expect(stopped.menuDisplayTitle == "db [Stopped]")
        #expect(stopped.menuStatusAccessibilityLabel == "Status: Stopped")
        #expect(running.menuDisplayTitle == "api [Running]")
        #expect(running.menuStatusAccessibilityLabel == "Status: Running")
        #expect(starting.menuDisplayTitle == "metrics [Starting]")
        #expect(starting.menuStatusAccessibilityLabel == "Status: Starting")
        #expect(errored.menuDisplayTitle == "job [Error]")
        #expect(errored.menuStatusAccessibilityLabel == "Status: Error")
    }

    @Test
    func applyConfigurationStartsEnabledRulesOnInitialLoad() async throws {
        let runner = StubProcessRunner()
        let runtime = TunnelRuntimeStore(
            commandBuilder: StubCommandBuilder(),
            processRunner: runner,
            logWriter: MemoryLogWriter()
        )

        await runtime.applyConfiguration(.fixture())

        let snapshot = await runtime.snapshot()
        let statuses = snapshot.groups.flatMap(\.rules).map(\.state.status)
        #expect(runner.startCount == 2)
        #expect(statuses.filter { $0 == .running }.count == 2)
        #expect(statuses.contains(.stopped))
    }

    @Test
    func startEnabledRulesStartsOnlyEnabledRules() async throws {
        let runner = StubProcessRunner()
        let runtime = TunnelRuntimeStore(
            commandBuilder: StubCommandBuilder(),
            processRunner: runner,
            logWriter: MemoryLogWriter()
        )

        await runtime.applyConfiguration(.fixture())
        await runtime.startEnabledRules()

        let snapshot = await runtime.snapshot()
        let statuses = snapshot.groups.flatMap(\.rules).map(\.state.status)
        #expect(statuses.contains(.running))
        #expect(statuses.contains(.stopped))
    }

    @Test
    func stopRuleTransitionsToStopped() async throws {
        let runner = StubProcessRunner()
        let runtime = TunnelRuntimeStore(
            commandBuilder: StubCommandBuilder(),
            processRunner: runner,
            logWriter: MemoryLogWriter()
        )

        await runtime.applyConfiguration(.fixture())
        let rule = RuleKey(kind: .ssh, groupID: "bastion", ruleID: "db")
        await runtime.startRule(rule)
        await runtime.stopRule(rule)
        try await Task.sleep(nanoseconds: 50_000_000)

        let snapshot = await runtime.snapshot()
        let dbRule = snapshot.groups
            .flatMap(\.rules)
            .first(where: { $0.id == rule })
        #expect(dbRule?.state.status == .stopped)
    }

    @Test
    func startGroupSkipsDisabledRules() async throws {
        let runner = StubProcessRunner()
        let runtime = TunnelRuntimeStore(
            commandBuilder: StubCommandBuilder(),
            processRunner: runner,
            logWriter: MemoryLogWriter()
        )

        await runtime.applyConfiguration(.fixture())
        await runtime.startGroup(GroupKey(kind: .ssh, id: "bastion"))

        let snapshot = await runtime.snapshot()
        let rules = snapshot.groups
            .first(where: { $0.id == GroupKey(kind: .ssh, id: "bastion") })?
            .rules
        let dbRule = rules?.first(where: { $0.id.ruleID == "db" })
        let disabledRule = rules?.first(where: { $0.id.ruleID == "disabled" })
        #expect(dbRule?.state.status == .running)
        #expect(disabledRule?.state.status == .stopped)
    }

    @Test
    func handleWakeWaitsForRestartStopCompletion() async throws {
        let runner = StubProcessRunner(stopMode: .manual)
        let runtime = TunnelRuntimeStore(
            commandBuilder: StubCommandBuilder(),
            processRunner: runner,
            logWriter: MemoryLogWriter()
        )
        let rule = RuleKey(kind: .ssh, groupID: "bastion", ruleID: "db")
        let completion = CompletionProbe()

        await runtime.applyConfiguration(.fixture())
        await runtime.startRule(rule)
        await runtime.beginSleep()

        let wakeTask = Task {
            await runtime.handleWake()
            await completion.markFinished()
        }

        try await Task.sleep(nanoseconds: 250_000_000)
        #expect(runner.startCount == 2)
        #expect(await completion.isFinished == false)

        runner.terminateAll()
        await wakeTask.value

        let snapshot = await runtime.snapshot()
        let restartedRule = snapshot.groups
            .flatMap(\.rules)
            .first(where: { $0.id == rule })
        #expect(runner.startCount == 4)
        #expect(restartedRule?.state.status == .running)
    }

    @Test
    func shutdownWaitsForProcessesToTerminate() async throws {
        let runner = StubProcessRunner(stopMode: .manual)
        let runtime = TunnelRuntimeStore(
            commandBuilder: StubCommandBuilder(),
            processRunner: runner,
            logWriter: MemoryLogWriter()
        )
        let rule = RuleKey(kind: .ssh, groupID: "bastion", ruleID: "db")
        let completion = CompletionProbe()

        await runtime.applyConfiguration(.fixture())
        await runtime.startRule(rule)

        let shutdownTask = Task {
            await runtime.shutdown()
            await completion.markFinished()
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(await completion.isFinished == false)

        runner.terminateAll()
        await shutdownTask.value

        let snapshot = await runtime.snapshot()
        let stoppedRule = snapshot.groups
            .flatMap(\.rules)
            .first(where: { $0.id == rule })
        #expect(stoppedRule?.state.status == .stopped)
    }

    @Test
    func shutdownReturnsAfterTimeoutWhenProcessDoesNotTerminate() async throws {
        let runner = StubProcessRunner(stopMode: .manual)
        let runtime = TunnelRuntimeStore(
            commandBuilder: StubCommandBuilder(),
            processRunner: runner,
            logWriter: MemoryLogWriter(),
            shutdownWaitTimeoutNanoseconds: 100_000_000
        )
        let rule = RuleKey(kind: .ssh, groupID: "bastion", ruleID: "db")
        let completion = CompletionProbe()

        await runtime.applyConfiguration(.fixture())
        await runtime.startRule(rule)

        let shutdownTask = Task {
            await runtime.shutdown()
            await completion.markFinished()
        }

        try await Task.sleep(nanoseconds: 250_000_000)
        #expect(await completion.isFinished == true)
        await shutdownTask.value
    }

    @Test
    func applyConfigurationStartsNewlyEnabledRules() async throws {
        let runner = StubProcessRunner()
        let runtime = TunnelRuntimeStore(
            commandBuilder: StubCommandBuilder(),
            processRunner: runner,
            logWriter: MemoryLogWriter()
        )
        let disabledRule = RuleKey(kind: .ssh, groupID: "bastion", ruleID: "disabled")

        await runtime.applyConfiguration(.fixture())
        await runtime.startEnabledRules()
        await runtime.applyConfiguration(.fixture(enableDisabledRule: true))

        let snapshot = await runtime.snapshot()
        let restartedRule = snapshot.groups
            .flatMap(\.rules)
            .first(where: { $0.id == disabledRule })
        #expect(restartedRule?.state.status == .running)
    }

    @Test
    func applyConfigurationKeepsPreviousStateOnCallerFailure() async throws {
        let runner = StubProcessRunner()
        let runtime = TunnelRuntimeStore(
            commandBuilder: StubCommandBuilder(),
            processRunner: runner,
            logWriter: MemoryLogWriter()
        )

        await runtime.applyConfiguration(.fixture())
        let initialGroups = await runtime.snapshot().groups.count
        #expect(initialGroups == 2)

        let invalid = AppConfiguration(version: 2, ssh: [], kubernetes: [])
        let validator = ConfigurationValidator()
        #expect(throws: ConfigurationValidationError.self) {
            try validator.validate(invalid)
        }

        let finalGroups = await runtime.snapshot().groups.count
        #expect(finalGroups == 2)
    }
}

private struct StubCommandBuilder: CommandBuilding {
    func makeCommand(for definition: RuleDefinition) throws -> ExecutableCommand {
        ExecutableCommand(executable: "/bin/echo", arguments: [definition.ruleTitle])
    }
}

private actor MemoryLogWriter: LogWriting {
    func write(line: String) async {}
}

private final class StubProcessRunner: ProcessRunning, @unchecked Sendable {
    enum StopMode {
        case immediate
        case manual
    }

    private let stopMode: StopMode
    private let lock = NSLock()
    private var nextPID: Int32 = 123
    private var emitters: [Int32: TestEmitter] = [:]
    private(set) var startCount = 0

    init(stopMode: StopMode = .immediate) {
        self.stopMode = stopMode
    }

    func start(command: ExecutableCommand) throws -> ManagedProcessSession {
        let emitter = TestEmitter()
        let stream = AsyncStream<ProcessEvent> { streamContinuation in
            emitter.continuation = streamContinuation
        }
        let pid = lock.withLock {
            let pid = nextPID
            nextPID += 1
            startCount += 1
            emitters[pid] = emitter
            return pid
        }
        return ManagedProcessSession(
            processIdentifier: pid,
            events: stream,
            stop: { [weak self] in
                self?.stop(pid: pid)
            }
        )
    }

    func terminateAll() {
        let emitters = lock.withLock {
            let active = Array(self.emitters.values)
            self.emitters.removeAll()
            return active
        }
        for emitter in emitters {
            emitter.finish()
        }
    }

    private func stop(pid: Int32) {
        let emitter = lock.withLock { () -> TestEmitter? in
            guard stopMode == .immediate else { return emitters[pid] }
            let emitter = emitters[pid]
            emitters.removeValue(forKey: pid)
            return emitter
        }

        guard let emitter else { return }
        if stopMode == .immediate {
            emitter.finish()
        }
    }
}

private func menuRule(
    kind: RuleKind = .ssh,
    groupID: String = "bastion",
    id: String,
    status: RuleStatus,
    isEnabled: Bool = true
) -> RuleSnapshot {
    RuleSnapshot(
        id: RuleKey(kind: kind, groupID: groupID, ruleID: id),
        title: id,
        subtitle: "subtitle",
        isEnabled: isEnabled,
        state: menuRuleState(for: status),
        lastLogLine: "last log"
    )
}

private func menuRuleState(for status: RuleStatus) -> RuleRuntimeState {
    switch status {
    case .stopped:
        return .stopped()
    case .starting:
        return .starting()
    case .running:
        return .running(pid: 123)
    case .error:
        return .failed(RuleErrorSummary(message: "failed"))
    }
}

private final class TestEmitter: @unchecked Sendable {
    var continuation: AsyncStream<ProcessEvent>.Continuation?

    func finish() {
        continuation?.yield(.terminated(0))
        continuation?.finish()
    }
}

private actor CompletionProbe {
    private(set) var isFinished = false

    func markFinished() {
        isFinished = true
    }
}

private extension AppConfiguration {
    static func fixture(enableDisabledRule: Bool = false) -> AppConfiguration {
        AppConfiguration(
            version: 1,
            ssh: [
                SSHHostConfig(
                    id: "bastion",
                    host: "example.local",
                    user: "ec2-user",
                    port: 22,
                    forwards: [
                        SSHForwardConfig(
                            id: "db",
                            localPort: 15432,
                            remoteHost: "127.0.0.1",
                            remotePort: 5432
                        ),
                        SSHForwardConfig(
                            id: "disabled",
                            enabled: enableDisabledRule,
                            localPort: 18000,
                            remoteHost: "127.0.0.1",
                            remotePort: 8000
                        )
                    ]
                )
            ],
            kubernetes: [
                KubernetesContextConfig(
                    id: "dev",
                    context: "dev",
                    forwards: [
                        KubernetesForwardConfig(
                            id: "api",
                            namespace: "default",
                            target: KubernetesTarget(kind: .svc, name: "api"),
                            localPort: 18080,
                            remotePort: 8080
                        )
                    ]
                )
            ]
        )
    }
}
