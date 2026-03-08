import SwiftUI

@main
struct TunnelasApp: App {
    @StateObject private var model = AppModel.bootstrap()

    var body: some Scene {
        MenuBarExtra("Tunnelas", systemImage: "point.3.connected.trianglepath.dotted") {
            MenuBarContentView(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Logs", id: "logs") {
            LogWindowView(model: model)
        }
        .defaultSize(width: 820, height: 520)

        Settings {
            SettingsView(model: model)
        }
    }
}
