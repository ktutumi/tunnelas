import Foundation
import TunnelasCore

public actor FileLogSink: LogWriting {
    public nonisolated let logFileURL: URL
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let logsDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Tunnelas", isDirectory: true)
        self.logFileURL = logsDirectory.appendingPathComponent("app.log", isDirectory: false)
    }

    public func write(line: String) async {
        do {
            let directory = logFileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let timestamp = ISO8601DateFormatter().string(from: Date())
            let payload = "\(timestamp) \(line)\n"
            let data = Data(payload.utf8)

            if fileManager.fileExists(atPath: logFileURL.path) {
                let handle = try FileHandle(forWritingTo: logFileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: logFileURL, options: .atomic)
            }
        } catch {
            fputs("Tunnelas log write failed: \(error)\n", stderr)
        }
    }
}
