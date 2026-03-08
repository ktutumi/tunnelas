import Foundation
import Testing
@testable import TunnelasCore

struct TunnelRuntimeStoreTests {
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
    func start(command: ExecutableCommand) throws -> ManagedProcessSession {
        let emitter = TestEmitter()
        let stream = AsyncStream<ProcessEvent> { streamContinuation in
            emitter.continuation = streamContinuation
        }
        return ManagedProcessSession(
            processIdentifier: 123,
            events: stream,
            stop: {
                emitter.finish()
            }
        )
    }
}

private final class TestEmitter: @unchecked Sendable {
    var continuation: AsyncStream<ProcessEvent>.Continuation?

    func finish() {
        continuation?.yield(.terminated(0))
        continuation?.finish()
    }
}

private extension AppConfiguration {
    static func fixture() -> AppConfiguration {
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
                            enabled: false,
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
