import Foundation
import TunnelasCore

public struct FileConfigurationLoader: ConfigurationLoading {
    public let configurationURL: URL

    public init(fileManager: FileManager = .default) {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        self.configurationURL = homeDirectory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("tunnelas", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }

    public init(configurationURL: URL) {
        self.configurationURL = configurationURL
    }

    public func loadConfigurationData() throws -> Data {
        try Data(contentsOf: configurationURL)
    }
}

