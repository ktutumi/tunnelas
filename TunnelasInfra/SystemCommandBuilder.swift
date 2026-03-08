import Foundation
import TunnelasCore

public struct SystemCommandBuilder: CommandBuilding {
    public init() {}

    public func makeCommand(for definition: RuleDefinition) throws -> ExecutableCommand {
        switch definition {
        case let .ssh(group, forward):
            return ExecutableCommand(
                executable: "/usr/bin/env",
                arguments: [
                    "ssh",
                    "-N",
                    "-p", String(group.port),
                    "-L", "\(forward.localPort):\(forward.remoteHost):\(forward.remotePort)",
                    "\(group.user)@\(group.host)"
                ]
            )
        case let .kubernetes(group, forward):
            return ExecutableCommand(
                executable: "/usr/bin/env",
                arguments: [
                    "kubectl",
                    "--context", group.context,
                    "--namespace", forward.namespace,
                    "port-forward",
                    "\(forward.target.kind.rawValue)/\(forward.target.name)",
                    "\(forward.localPort):\(forward.remotePort)"
                ]
            )
        }
    }
}

