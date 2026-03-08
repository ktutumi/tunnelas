import Foundation
import Testing
@testable import TunnelasCore

struct ConfigurationValidatorTests {
    private let validator = ConfigurationValidator()

    @Test
    func validConfigurationPasses() throws {
        let configuration = AppConfiguration(
            version: 1,
            ssh: [
                SSHHostConfig(
                    id: "bastion",
                    host: "example.local",
                    user: "ec2-user",
                    port: 22,
                    forwards: [
                        SSHForwardConfig(
                            id: "db",
                            localPort: 15432,
                            remoteHost: "127.0.0.1",
                            remotePort: 5432,
                            tags: ["database", "critical"]
                        )
                    ]
                )
            ],
            kubernetes: [
                KubernetesContextConfig(
                    id: "dev",
                    context: "dev",
                    forwards: [
                        KubernetesForwardConfig(
                            id: "api",
                            namespace: "default",
                            target: KubernetesTarget(kind: .svc, name: "api"),
                            localPort: 18080,
                            remotePort: 8080
                        )
                    ]
                )
            ]
        )

        #expect(throws: Never.self) {
            try validator.validate(configuration)
        }
    }

    @Test
    func duplicateSSHIDsFail() throws {
        let configuration = AppConfiguration(
            version: 1,
            ssh: [
                SSHHostConfig(id: "dup", host: "one", user: "u", port: 22, forwards: []),
                SSHHostConfig(id: "dup", host: "two", user: "u", port: 22, forwards: [])
            ],
            kubernetes: []
        )

        #expect(throws: ConfigurationValidationError.self) {
            try validator.validate(configuration)
        }
    }

    @Test
    func invalidTagsFail() throws {
        let configuration = AppConfiguration(
            version: 1,
            ssh: [
                SSHHostConfig(
                    id: "bastion",
                    host: "example.local",
                    user: "ec2-user",
                    port: 22,
                    forwards: [
                        SSHForwardConfig(
                            id: "db",
                            localPort: 15432,
                            remoteHost: "127.0.0.1",
                            remotePort: 5432,
                            tags: [" db", "db"]
                        )
                    ]
                )
            ],
            kubernetes: []
        )

        #expect(throws: ConfigurationValidationError.self) {
            try validator.validate(configuration)
        }
    }

    @Test
    func invalidKubernetesPortFails() throws {
        let configuration = AppConfiguration(
            version: 1,
            ssh: [],
            kubernetes: [
                KubernetesContextConfig(
                    id: "dev",
                    context: "dev",
                    forwards: [
                        KubernetesForwardConfig(
                            id: "api",
                            namespace: "default",
                            target: KubernetesTarget(kind: .svc, name: "api"),
                            localPort: 70000,
                            remotePort: 8080
                        )
                    ]
                )
            ]
        )

        #expect(throws: ConfigurationValidationError.self) {
            try validator.validate(configuration)
        }
    }
}

