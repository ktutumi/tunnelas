import Foundation

public struct ConfigurationValidationError: Error, Equatable, Sendable, LocalizedError {
    public let issues: [String]

    public init(issues: [String]) {
        self.issues = issues
    }

    public var errorDescription: String? {
        issues.joined(separator: "\n")
    }
}

public protocol ConfigurationValidating: Sendable {
    func validate(_ configuration: AppConfiguration) throws
}

public struct ConfigurationValidator: ConfigurationValidating {
    public init() {}

    public func validate(_ configuration: AppConfiguration) throws {
        var issues: [String] = []

        if configuration.version != 1 {
            issues.append("version must be 1")
        }

        issues.append(contentsOf: validateSSH(configuration.ssh))
        issues.append(contentsOf: validateKubernetes(configuration.kubernetes))

        if !issues.isEmpty {
            throw ConfigurationValidationError(issues: issues)
        }
    }

    private func validateSSH(_ hosts: [SSHHostConfig]) -> [String] {
        var issues: [String] = []
        var hostIDs = Set<String>()

        for host in hosts {
            if !hostIDs.insert(host.id).inserted {
                issues.append("duplicate ssh id: \(host.id)")
            }
            if !(1...65535).contains(host.port) {
                issues.append("ssh port out of range: \(host.id)")
            }

            var forwardIDs = Set<String>()
            for forward in host.forwards {
                if !forwardIDs.insert(forward.id).inserted {
                    issues.append("duplicate ssh forward id: \(host.id).\(forward.id)")
                }
                if !(1...65535).contains(forward.localPort) {
                    issues.append("ssh localPort out of range: \(host.id).\(forward.id)")
                }
                if !(1...65535).contains(forward.remotePort) {
                    issues.append("ssh remotePort out of range: \(host.id).\(forward.id)")
                }

                var normalizedTags = Set<String>()
                for tag in forward.tags {
                    if tag.isEmpty {
                        issues.append("ssh tag must not be empty: \(host.id).\(forward.id)")
                        continue
                    }
                    let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed != tag {
                        issues.append("ssh tag must not contain leading or trailing spaces: \(host.id).\(forward.id)")
                    }
                    if !trimmed.isEmpty && !normalizedTags.insert(trimmed).inserted {
                        issues.append("ssh tags must be unique after trimming: \(host.id).\(forward.id)")
                    }
                }
            }
        }

        return issues
    }

    private func validateKubernetes(_ contexts: [KubernetesContextConfig]) -> [String] {
        var issues: [String] = []
        var contextIDs = Set<String>()

        for context in contexts {
            if !contextIDs.insert(context.id).inserted {
                issues.append("duplicate kubernetes id: \(context.id)")
            }

            var forwardIDs = Set<String>()
            for forward in context.forwards {
                if !forwardIDs.insert(forward.id).inserted {
                    issues.append("duplicate kubernetes forward id: \(context.id).\(forward.id)")
                }
                if !(1...65535).contains(forward.localPort) {
                    issues.append("kubernetes localPort out of range: \(context.id).\(forward.id)")
                }
                if !(1...65535).contains(forward.remotePort) {
                    issues.append("kubernetes remotePort out of range: \(context.id).\(forward.id)")
                }
            }
        }

        return issues
    }
}

