import Foundation

public struct AppConfiguration: Codable, Equatable, Sendable {
    public let version: Int
    public let ssh: [SSHHostConfig]
    public let kubernetes: [KubernetesContextConfig]

    public init(version: Int, ssh: [SSHHostConfig], kubernetes: [KubernetesContextConfig]) {
        self.version = version
        self.ssh = ssh
        self.kubernetes = kubernetes
    }
}

public struct SSHHostConfig: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let enabled: Bool
    public let host: String
    public let user: String
    public let port: Int
    public let forwards: [SSHForwardConfig]

    public init(id: String, enabled: Bool = true, host: String, user: String, port: Int, forwards: [SSHForwardConfig]) {
        self.id = id
        self.enabled = enabled
        self.host = host
        self.user = user
        self.port = port
        self.forwards = forwards
    }

    enum CodingKeys: String, CodingKey {
        case id
        case enabled
        case host
        case user
        case port
        case forwards
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        host = try container.decode(String.self, forKey: .host)
        user = try container.decode(String.self, forKey: .user)
        port = try container.decode(Int.self, forKey: .port)
        forwards = try container.decode([SSHForwardConfig].self, forKey: .forwards)
    }
}

public struct SSHForwardConfig: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let enabled: Bool
    public let localPort: Int
    public let remoteHost: String
    public let remotePort: Int
    public let tags: [String]

    public init(id: String, enabled: Bool = true, localPort: Int, remoteHost: String, remotePort: Int, tags: [String] = []) {
        self.id = id
        self.enabled = enabled
        self.localPort = localPort
        self.remoteHost = remoteHost
        self.remotePort = remotePort
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id
        case enabled
        case localPort
        case remoteHost
        case remotePort
        case tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        localPort = try container.decode(Int.self, forKey: .localPort)
        remoteHost = try container.decode(String.self, forKey: .remoteHost)
        remotePort = try container.decode(Int.self, forKey: .remotePort)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

public struct KubernetesContextConfig: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let enabled: Bool
    public let context: String
    public let forwards: [KubernetesForwardConfig]

    public init(id: String, enabled: Bool = true, context: String, forwards: [KubernetesForwardConfig]) {
        self.id = id
        self.enabled = enabled
        self.context = context
        self.forwards = forwards
    }

    enum CodingKeys: String, CodingKey {
        case id
        case enabled
        case context
        case forwards
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        context = try container.decode(String.self, forKey: .context)
        forwards = try container.decode([KubernetesForwardConfig].self, forKey: .forwards)
    }
}

public struct KubernetesForwardConfig: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let enabled: Bool
    public let namespace: String
    public let target: KubernetesTarget
    public let localPort: Int
    public let remotePort: Int

    public init(
        id: String,
        enabled: Bool = true,
        namespace: String,
        target: KubernetesTarget,
        localPort: Int,
        remotePort: Int
    ) {
        self.id = id
        self.enabled = enabled
        self.namespace = namespace
        self.target = target
        self.localPort = localPort
        self.remotePort = remotePort
    }

    enum CodingKeys: String, CodingKey {
        case id
        case enabled
        case namespace
        case target
        case localPort
        case remotePort
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        namespace = try container.decode(String.self, forKey: .namespace)
        target = try container.decode(KubernetesTarget.self, forKey: .target)
        localPort = try container.decode(Int.self, forKey: .localPort)
        remotePort = try container.decode(Int.self, forKey: .remotePort)
    }
}

public struct KubernetesTarget: Codable, Equatable, Sendable {
    public let kind: ForwardTargetKind
    public let name: String

    public init(kind: ForwardTargetKind, name: String) {
        self.kind = kind
        self.name = name
    }
}

public enum ForwardTargetKind: String, Codable, Equatable, Sendable, CaseIterable {
    case svc
    case pod
}

