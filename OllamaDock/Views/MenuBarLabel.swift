import SwiftUI

struct MenuBarLabel: View {
    let daemonUp: Bool
    let modelRunning: Bool
    let totalVRAM: UInt64

    var body: some View {
        HStack(spacing: 4) {
            // The menu bar tints any SwiftUI content in its label as a template,
            // which strips our colors. Rendering the dot to a non-template
            // NSImage is the only reliable way to keep the green/white fill.
            Image(nsImage: dotImage)
            if daemonUp {
                Text(ByteFormatter.format(totalVRAM))
                    .monospacedDigit()
            }
        }
    }

    // Single dot = model status. Green = a model is loaded, white = none.
    private var dotImage: NSImage {
        let renderer = ImageRenderer(content: dot)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = false
        return image
    }

    private var dot: some View {
        Circle()
            .fill(modelRunning ? Color(nsColor: .systemGreen) : Color.white)
            .frame(width: 7, height: 7)
            .padding(2)
    }
}
