import Foundation

public struct GroupDefinition: Equatable, Sendable {
    public let key: GroupKey
    public let title: String
    public let isEnabled: Bool
    public let ruleKeys: [RuleKey]
}

public enum RuleDefinition: Equatable, Sendable {
    case ssh(group: SSHHostConfig, forward: SSHForwardConfig)
    case kubernetes(group: KubernetesContextConfig, forward: KubernetesForwardConfig)

    public var key: RuleKey {
        switch self {
        case let .ssh(group, forward):
            return RuleKey(kind: .ssh, groupID: group.id, ruleID: forward.id)
        case let .kubernetes(group, forward):
            return RuleKey(kind: .kubernetes, groupID: group.id, ruleID: forward.id)
        }
    }

    public var groupKey: GroupKey {
        switch self {
        case let .ssh(group, _):
            return GroupKey(kind: .ssh, id: group.id)
        case let .kubernetes(group, _):
            return GroupKey(kind: .kubernetes, id: group.id)
        }
    }

    public var isEnabled: Bool {
        switch self {
        case let .ssh(group, forward):
            return group.enabled && forward.enabled
        case let .kubernetes(group, forward):
            return group.enabled && forward.enabled
        }
    }

    public var groupTitle: String {
        switch self {
        case let .ssh(group, _):
            return "\(group.id) (\(group.user)@\(group.host))"
        case let .kubernetes(group, _):
            return "\(group.id) (\(group.context))"
        }
    }

    public var ruleTitle: String {
        switch self {
        case let .ssh(_, forward):
            return forward.id
        case let .kubernetes(_, forward):
            return forward.id
        }
    }

    public var ruleSubtitle: String {
        switch self {
        case let .ssh(_, forward):
            return "localhost:\(forward.localPort) -> \(forward.remoteHost):\(forward.remotePort)"
        case let .kubernetes(_, forward):
            return "\(forward.namespace)/\(forward.target.kind.rawValue)/\(forward.target.name) : \(forward.localPort)->\(forward.remotePort)"
        }
    }
}

public struct ConfigurationIndex: Equatable, Sendable {
    public let groups: [GroupDefinition]
    public let rulesByKey: [RuleKey: RuleDefinition]

    public init(configuration: AppConfiguration) {
        var groups: [GroupDefinition] = []
        var rulesByKey: [RuleKey: RuleDefinition] = [:]

        for sshGroup in configuration.ssh {
            let groupKey = GroupKey(kind: .ssh, id: sshGroup.id)
            let definitions = sshGroup.forwards.map { RuleDefinition.ssh(group: sshGroup, forward: $0) }
            groups.append(
                GroupDefinition(
                    key: groupKey,
                    title: "\(sshGroup.id) (\(sshGroup.user)@\(sshGroup.host))",
                    isEnabled: sshGroup.enabled,
                    ruleKeys: definitions.map(\.key)
                )
            )
            for definition in definitions {
                rulesByKey[definition.key] = definition
            }
        }

        for kubernetesGroup in configuration.kubernetes {
            let groupKey = GroupKey(kind: .kubernetes, id: kubernetesGroup.id)
            let definitions = kubernetesGroup.forwards.map { RuleDefinition.kubernetes(group: kubernetesGroup, forward: $0) }
            groups.append(
                GroupDefinition(
                    key: groupKey,
                    title: "\(kubernetesGroup.id) (\(kubernetesGroup.context))",
                    isEnabled: kubernetesGroup.enabled,
                    ruleKeys: definitions.map(\.key)
                )
            )
            for definition in definitions {
                rulesByKey[definition.key] = definition
            }
        }

        self.groups = groups
        self.rulesByKey = rulesByKey
    }
}

