import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            LabeledContent("Config File") {
                Text(model.configurationURL.path)
                    .textSelection(.enabled)
            }

            LabeledContent("Log File") {
                Text(model.logFileURL.path)
                    .textSelection(.enabled)
            }

            if let error = model.configurationError {
                LabeledContent("Last Error") {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Button("Reload Configuration") {
                    model.reloadConfiguration()
                }
                Button("Open Config Folder") {
                    model.openConfigFolder()
                }
                Button("Open Log File") {
                    model.openLogFile()
                }
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}

