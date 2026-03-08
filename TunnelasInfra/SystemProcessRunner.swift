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

        let stdoutMonitor = PipeReadMonitor(fileHandle: stdoutPipe.fileHandleForReading) { data in
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
            emitter.yield(.stdout(text))
        }

        let stderrMonitor = PipeReadMonitor(fileHandle: stderrPipe.fileHandleForReading) { data in
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return }
            emitter.yield(.stderr(text))
        }

        process.terminationHandler = { terminatedProcess in
            stdoutMonitor.cancel()
            stderrMonitor.cancel()
            emitter.yield(.terminated(terminatedProcess.terminationStatus))
            emitter.finish()
        }

        do {
            try process.run()
        } catch {
            stdoutMonitor.cancel()
            stderrMonitor.cancel()
            throw error
        }

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

final class PipeReadMonitor: @unchecked Sendable {
    private static let queue = DispatchQueue(
        label: "com.ktutumi.tunnelas.pipe-read-monitor",
        qos: .utility,
        attributes: .concurrent
    )

    private let fileHandle: FileHandle
    private let source: DispatchSourceRead
    private let onData: @Sendable (Data) -> Void
    private let onEOF: @Sendable () -> Void
    private let stateLock = NSLock()
    private var isCancelled = false

    init(
        fileHandle: FileHandle,
        queue: DispatchQueue = PipeReadMonitor.queue,
        onData: @escaping @Sendable (Data) -> Void,
        onEOF: @escaping @Sendable () -> Void = {}
    ) {
        self.fileHandle = fileHandle
        self.onData = onData
        self.onEOF = onEOF
        self.source = DispatchSource.makeReadSource(fileDescriptor: fileHandle.fileDescriptor, queue: queue)
        source.setEventHandler { [weak self] in
            self?.handleReadableEvent()
        }
        source.resume()
    }

    func cancel() {
        stateLock.lock()
        let shouldCancel = !isCancelled
        isCancelled = true
        stateLock.unlock()

        guard shouldCancel else { return }
        source.cancel()
    }

    private func handleReadableEvent() {
        let byteCount = max(Int(source.data), 1)
        let data = (try? fileHandle.read(upToCount: byteCount)) ?? Data()

        guard !data.isEmpty else {
            cancel()
            onEOF()
            return
        }

        onData(data)
    }
}
