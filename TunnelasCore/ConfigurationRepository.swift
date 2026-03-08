import Foundation

public protocol ConfigurationLoading: Sendable {
    var configurationURL: URL { get }
    func loadConfigurationData() throws -> Data
}

public protocol ConfigurationRepository: Sendable {
    var configurationURL: URL { get }
    func load() throws -> AppConfiguration
}

public struct DefaultConfigurationRepository: ConfigurationRepository {
    private let loader: any ConfigurationLoading
    private let validator: any ConfigurationValidating
    private let decoder: JSONDecoder

    public init(
        loader: any ConfigurationLoading,
        validator: any ConfigurationValidating = ConfigurationValidator(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.loader = loader
        self.validator = validator
        self.decoder = decoder
    }

    public var configurationURL: URL {
        loader.configurationURL
    }

    public func load() throws -> AppConfiguration {
        let data = try loader.loadConfigurationData()
        let configuration = try decoder.decode(AppConfiguration.self, from: data)
        try validator.validate(configuration)
        return configuration
    }
}

