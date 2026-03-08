import Foundation
import TunnelasCore

public struct SystemProcessRunner: ProcessRunning {
    public init() {}

    public func start(command: ExecutableCommand) throws -> ManagedProcessSession {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let emitter = ProcessEmitter()

        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        if !command.environment.isEmpty {
            process.environment = ProcessInfo.processInfo.environment.merging(command.environment) { _, new in new }
        }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            emitter.yield(.stdout(text))
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            emitter.yield(.stderr(text))
        }

        process.terminationHandler = { terminatedProcess in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            emitter.yield(.terminated(terminatedProcess.terminationStatus))
            emitter.finish()
        }

        try process.run()

        return ManagedProcessSession(
            processIdentifier: process.processIdentifier,
            events: emitter.stream,
            stop: { process.terminate() }
        )
    }
}

private final class ProcessEmitter: @unchecked Sendable {
    let stream: AsyncStream<ProcessEvent>
    private let continuation: AsyncStream<ProcessEvent>.Continuation

    init() {
        var storedContinuation: AsyncStream<ProcessEvent>.Continuation?
        self.stream = AsyncStream { continuation in
            storedContinuation = continuation
        }
        self.continuation = storedContinuation!
    }

    func yield(_ event: ProcessEvent) {
        continuation.yield(event)
    }

    func finish() {
        continuation.finish()
    }
}

