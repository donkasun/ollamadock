import SwiftUI

@main
struct OllamaDockApp: App {
    @State private var monitor = ModelMonitor(client: OllamaClient())

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
                .onAppear { monitor.start() }
        } label: {
            MenuBarLabel(totalVRAM: monitor.totalVRAM)
        }
        .menuBarExtraStyle(.window)
    }
}
