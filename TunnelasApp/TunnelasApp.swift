import SwiftUI

@main
struct TunnelasApp: App {
    @StateObject private var model = AppModel.bootstrap()

    var body: some Scene {
        MenuBarExtra("Tunnelas", systemImage: model.snapshot.menuSummary.menuBarIconName) {
            MenuBarContentView(model: model)
        }

        Window("Logs", id: "logs") {
            LogWindowView(model: model)
        }
        .defaultSize(width: 820, height: 520)

        Settings {
            SettingsView(model: model)
        }
    }
}
