import SwiftUI

@main
struct MangaPDFTranslatorApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var appModel: AppModel

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _appModel = StateObject(wrappedValue: AppModel(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .environmentObject(settings)
                .frame(minWidth: 720, minHeight: 560)
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .frame(width: 560)
        }
    }
}
