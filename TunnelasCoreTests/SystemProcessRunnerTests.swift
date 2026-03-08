import Foundation
import Testing
@testable import TunnelasInfra

struct SystemProcessRunnerTests {
    @Test
    func pipeReadMonitorDoesNotEmitForIdleOpenPipe() async throws {
        let pipe = Pipe()
        let probe = PipeReadMonitorProbe()
        let monitor = PipeReadMonitor(
            fileHandle: pipe.fileHandleForReading,
            onData: { data in
                Task { await probe.record(data) }
            },
            onEOF: {
                Task { await probe.finish() }
            }
        )

        defer {
            monitor.cancel()
            pipe.fileHandleForWriting.closeFile()
        }

        try await Task.sleep(nanoseconds: 100_000_000)

        let snapshot = await probe.snapshot()
        #expect(snapshot.chunks.isEmpty)
        #expect(snapshot.didFinish == false)
    }

    @Test
    func pipeReadMonitorEmitsDataAndFinishesAfterWriterCloses() async throws {
        let pipe = Pipe()
        let probe = PipeReadMonitorProbe()
        let monitor = PipeReadMonitor(
            fileHandle: pipe.fileHandleForReading,
            onData: { data in
                Task { await probe.record(data) }
            },
            onEOF: {
                Task { await probe.finish() }
            }
        )

        defer {
            monitor.cancel()
        }

        pipe.fileHandleForWriting.write(Data("hello".utf8))
        pipe.fileHandleForWriting.closeFile()

        let didFinish = await probe.waitUntilFinished(timeoutNanoseconds: 1_000_000_000)
        let snapshot = await probe.snapshot()

        #expect(didFinish == true)
        #expect(String(decoding: snapshot.chunks.joined(), as: UTF8.self) == "hello")
    }
}

private actor PipeReadMonitorProbe {
    struct Snapshot {
        let chunks: [Data]
        let didFinish: Bool
    }

    private var chunks: [Data] = []
    private var didFinish = false

    func record(_ data: Data) {
        chunks.append(data)
    }

    func finish() {
        didFinish = true
    }

    func snapshot() -> Snapshot {
        Snapshot(chunks: chunks, didFinish: didFinish)
    }

    func waitUntilFinished(timeoutNanoseconds: UInt64) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while !didFinish {
            if DispatchTime.now().uptimeNanoseconds >= deadline {
                return false
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }
}
