import SwiftUI

@main
struct OllamaDockApp: App {
    @State private var monitor: ModelMonitor

    init() {
        let monitor = ModelMonitor(
            client: OllamaClient(),
            daemonController: DaemonController()
        )
        monitor.start()
        _monitor = State(wrappedValue: monitor)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(monitor: monitor)
        } label: {
            MenuBarLabel(
                daemonUp: monitor.daemonUp,
                modelRunning: monitor.modelRunning,
                totalVRAM: monitor.totalVRAM
            )
        }
        .menuBarExtraStyle(.window)
    }
}
