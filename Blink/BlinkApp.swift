import SwiftUI

@main
struct BlinkApp: App {
    var body: some Scene {
        MenuBarExtra("Blink", systemImage: "clock") {
            Text("Blink is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
