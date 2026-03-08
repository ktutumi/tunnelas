import Foundation

public enum RuleKind: String, Codable, CaseIterable, Sendable {
    case ssh
    case kubernetes
}

public struct GroupKey: Hashable, Codable, Sendable {
    public let kind: RuleKind
    public let id: String

    public init(kind: RuleKind, id: String) {
        self.kind = kind
        self.id = id
    }
}

public struct RuleKey: Hashable, Codable, Sendable {
    public let kind: RuleKind
    public let groupID: String
    public let ruleID: String

    public init(kind: RuleKind, groupID: String, ruleID: String) {
        self.kind = kind
        self.groupID = groupID
        self.ruleID = ruleID
    }
}

public enum RuleStatus: String, Codable, Sendable {
    case stopped
    case starting
    case running
    case error
}

public struct RuleErrorSummary: Equatable, Codable, Sendable {
    public let message: String
    public let suggestion: String?

    public init(message: String, suggestion: String? = nil) {
        self.message = message
        self.suggestion = suggestion
    }
}

public struct RuleRuntimeState: Equatable, Codable, Sendable {
    public let status: RuleStatus
    public let processIdentifier: Int32?
    public let error: RuleErrorSummary?
    public let updatedAt: Date

    public init(status: RuleStatus, processIdentifier: Int32?, error: RuleErrorSummary?, updatedAt: Date = Date()) {
        self.status = status
        self.processIdentifier = processIdentifier
        self.error = error
        self.updatedAt = updatedAt
    }

    public static func stopped() -> RuleRuntimeState {
        RuleRuntimeState(status: .stopped, processIdentifier: nil, error: nil)
    }

    public static func starting() -> RuleRuntimeState {
        RuleRuntimeState(status: .starting, processIdentifier: nil, error: nil)
    }

    public static func running(pid: Int32?) -> RuleRuntimeState {
        RuleRuntimeState(status: .running, processIdentifier: pid, error: nil)
    }

    public static func failed(_ error: RuleErrorSummary) -> RuleRuntimeState {
        RuleRuntimeState(status: .error, processIdentifier: nil, error: error)
    }
}

public struct LogEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let text: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), text: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
    }
}

public struct RuleSnapshot: Identifiable, Equatable, Sendable {
    public let id: RuleKey
    public let title: String
    public let subtitle: String
    public let isEnabled: Bool
    public let state: RuleRuntimeState
    public let lastLogLine: String?

    public init(id: RuleKey, title: String, subtitle: String, isEnabled: Bool, state: RuleRuntimeState, lastLogLine: String?) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.isEnabled = isEnabled
        self.state = state
        self.lastLogLine = lastLogLine
    }
}

public struct GroupSnapshot: Identifiable, Equatable, Sendable {
    public let id: GroupKey
    public let title: String
    public let isEnabled: Bool
    public let rules: [RuleSnapshot]

    public init(id: GroupKey, title: String, isEnabled: Bool, rules: [RuleSnapshot]) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
        self.rules = rules
    }
}

public struct RuntimeSnapshot: Equatable, Sendable {
    public let groups: [GroupSnapshot]

    public init(groups: [GroupSnapshot]) {
        self.groups = groups
    }

    public static let empty = RuntimeSnapshot(groups: [])
}

public struct ExecutableCommand: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]
    public let environment: [String: String]

    public init(executable: String, arguments: [String], environment: [String: String] = [:]) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
    }

    public var shellDescription: String {
        ([executable] + arguments).joined(separator: " ")
    }
}

public enum ProcessEvent: Sendable {
    case stdout(String)
    case stderr(String)
    case terminated(Int32?)
}

public struct ManagedProcessSession: Sendable {
    public let processIdentifier: Int32?
    public let events: AsyncStream<ProcessEvent>
    public let stop: @Sendable () -> Void

    public init(processIdentifier: Int32?, events: AsyncStream<ProcessEvent>, stop: @Sendable @escaping () -> Void) {
        self.processIdentifier = processIdentifier
        self.events = events
        self.stop = stop
    }
}

public protocol CommandBuilding: Sendable {
    func makeCommand(for definition: RuleDefinition) throws -> ExecutableCommand
}

public protocol ProcessRunning: Sendable {
    func start(command: ExecutableCommand) throws -> ManagedProcessSession
}

public protocol LogWriting: Sendable {
    func write(line: String) async
}

