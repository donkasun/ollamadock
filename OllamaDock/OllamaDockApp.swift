import SwiftUI

@main
struct OllamaDockApp: App {
    var body: some Scene {
        MenuBarExtra("OllamaDock", systemImage: "cpu") {
            Text("Hello, OllamaDock")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
