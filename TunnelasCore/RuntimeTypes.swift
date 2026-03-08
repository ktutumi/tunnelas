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

public extension RuleStatus {
    var menuStatusGlyph: String {
        switch self {
        case .stopped:
            return "○"
        case .starting:
            return "◐"
        case .running:
            return "●"
        case .error:
            return "▲"
        }
    }

    var menuStatusText: String {
        switch self {
        case .stopped:
            return "Stopped"
        case .starting:
            return "Starting"
        case .running:
            return "Running"
        case .error:
            return "Error"
        }
    }

    var menuStatusSymbolName: String {
        switch self {
        case .stopped:
            return "xmark.circle"
        case .starting:
            return "arrow.clockwise.circle"
        case .running:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var menuStatusAccessibilityLabel: String {
        "Status: \(menuStatusText)"
    }
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

public struct RuntimeMenuSummary: Equatable, Sendable {
    public let totalRules: Int
    public let runningRules: Int
    public let startingRules: Int
    public let errorRules: Int

    public init(totalRules: Int, runningRules: Int, startingRules: Int, errorRules: Int) {
        self.totalRules = totalRules
        self.runningRules = runningRules
        self.startingRules = startingRules
        self.errorRules = errorRules
    }

    public var statusLine: String {
        "Running \(runningRules)/\(totalRules)  Starting \(startingRules)  Errors \(errorRules)"
    }

    public var menuBarIconName: String {
        if errorRules > 0 {
            return "exclamationmark.triangle.fill"
        }
        if startingRules > 0 {
            return "arrow.clockwise.circle"
        }
        return "point.3.connected.trianglepath.dotted"
    }
}

public extension RuntimeSnapshot {
    var menuSummary: RuntimeMenuSummary {
        let rules = groups.flatMap(\.rules)
        return RuntimeMenuSummary(
            totalRules: rules.count,
            runningRules: rules.filter { $0.state.status == .running }.count,
            startingRules: rules.filter { $0.state.status == .starting }.count,
            errorRules: rules.filter { $0.state.status == .error }.count
        )
    }
}

public extension GroupSnapshot {
    var menuStatus: RuleStatus {
        if errorRuleCount > 0 {
            return .error
        }
        if startingRuleCount > 0 {
            return .starting
        }
        if runningRuleCount > 0 {
            return .running
        }
        return .stopped
    }

    var menuStatusText: String {
        menuStatus.menuStatusText
    }

    var menuStatusSymbolName: String {
        menuStatus.menuStatusSymbolName
    }

    var menuStatusAccessibilityLabel: String {
        menuStatus.menuStatusAccessibilityLabel
    }

    var menuDisplayTitle: String {
        "\(menuStatus.menuStatusGlyph) \(title)"
    }

    var runningRuleCount: Int {
        rules.filter { $0.state.status == .running }.count
    }

    var startingRuleCount: Int {
        rules.filter { $0.state.status == .starting }.count
    }

    var errorRuleCount: Int {
        rules.filter { $0.state.status == .error }.count
    }

    var hasEnabledRules: Bool {
        rules.contains(where: \.isEnabled)
    }

    var canStartAnyRule: Bool {
        rules.contains(where: \.canStartFromMenu)
    }

    var canStopAnyRule: Bool {
        rules.contains(where: \.canStopFromMenu)
    }

    var menuSummaryLine: String {
        var parts = ["\(runningRuleCount)/\(rules.count) running"]
        if startingRuleCount > 0 {
            parts.append("\(startingRuleCount) starting")
        }
        if errorRuleCount > 0 {
            parts.append("\(errorRuleCount) errors")
        }
        return parts.joined(separator: "  ")
    }

    var menuSymbolName: String {
        if errorRuleCount > 0 {
            return "exclamationmark.triangle.fill"
        }
        if startingRuleCount > 0 {
            return "arrow.clockwise.circle"
        }
        if runningRuleCount > 0 {
            return "play.circle.fill"
        }
        return "pause.circle"
    }
}

public extension RuleSnapshot {
    var statusText: String {
        state.status.menuStatusText
    }

    var menuDisplayTitle: String {
        "\(state.status.menuStatusGlyph) \(title)"
    }

    var menuStatusSymbolName: String {
        state.status.menuStatusSymbolName
    }

    var menuStatusAccessibilityLabel: String {
        state.status.menuStatusAccessibilityLabel
    }

    var menuSymbolName: String {
        switch state.status {
        case .stopped:
            return "pause.circle"
        case .starting:
            return "arrow.clockwise.circle"
        case .running:
            return "play.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    var canStartFromMenu: Bool {
        isEnabled && state.status != .running && state.status != .starting
    }

    var canStopFromMenu: Bool {
        state.status == .running || state.status == .starting
    }
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
