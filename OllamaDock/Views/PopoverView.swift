import SwiftUI

struct PopoverView: View {
    @Bindable var monitor: ModelMonitor
    @State private var showQuitConfirm = false
    @State private var showStopAllConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            statusBar
            content
            if let error = monitor.lastUnloadError
                            ?? monitor.lastLoadError
                            ?? monitor.lastDaemonError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            footer
            if showStopAllConfirm {
                stopAllConfirmation
            }
            if showQuitConfirm {
                quitConfirmation
            }
        }
        .padding(12)
        .frame(width: 340)
        .onAppear {
            monitor.startTicking()
            monitor.clearActionErrors()
        }
        .onDisappear { monitor.stopTicking() }
    }

    private var stopAllConfirmation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Text("Stop all running models?")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.15)) { showStopAllConfirm = false }
                }
                .buttonStyle(.bordered)
                Button("Stop All", role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.15)) { showStopAllConfirm = false }
                    Task { await monitor.unloadAll() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var quitConfirmation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Text("Quit OllamaDock?")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.15)) { showQuitConfirm = false }
                }
                .buttonStyle(.bordered)
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var header: some View {
        HStack {
            Text("OllamaDock")
                .font(.headline)
            Spacer()
            Text("\(monitor.models.count) running · \(ByteFormatter.format(monitor.totalVRAM))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 16) {
            StatusIndicator(
                active: monitor.daemonUp,
                label: monitor.daemonUp ? "Ollama running" : "Ollama stopped"
            )
            StatusIndicator(
                active: monitor.modelRunning,
                label: monitor.modelRunning ? "Model loaded" : "No model loaded"
            )
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch monitor.state {
        case .loading:
            HStack { ProgressView(); Text("Checking…") }
                .frame(maxWidth: .infinity, minHeight: 80)

        case .unreachable:
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                if monitor.daemonNotInstalled {
                    Text("Ollama isn't installed")
                        .font(.subheadline)
                    Link(
                        "Get Ollama at ollama.com",
                        destination: URL(string: "https://ollama.com")!
                    )
                    .font(.caption)
                } else {
                    Text("Ollama isn't running")
                        .font(.subheadline)
                    Button("Start Ollama") {
                        Task { await monitor.startDaemon() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(monitor.isDaemonStarting)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80)

        case .protocolError(let message):
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                Text("Ollama responded unexpectedly")
                    .font(.subheadline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 80)

        case .connected:
            if monitor.models.isEmpty && monitor.availableModels.isEmpty {
                VStack(spacing: 4) {
                    Text("No models loaded")
                        .font(.subheadline)
                    Text("Run a model to see it here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                VStack(spacing: 6) {
                    if !monitor.models.isEmpty {
                        SectionHeader("Running")
                        ForEach(monitor.models) { model in
                            ModelRow(
                                model: model,
                                now: monitor.now,
                                onUnload: { Task { await monitor.unload(model.name) } }
                            )
                        }
                    }
                    if !monitor.availableModels.isEmpty {
                        SectionHeader("Available")
                        ForEach(monitor.availableModels) { model in
                            LibraryRow(
                                model: model,
                                isLoading: monitor.loadingModels.contains(model.name),
                                onLoad: { Task { await monitor.load(model.name) } }
                            )
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                Task {
                    await monitor.refresh()
                    await monitor.refreshLibrary()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .clipShape(Circle())
            .padding(.leading, -8)
            .help("Refresh")

            Spacer()

            Button("Stop All") {
                withAnimation(.easeInOut(duration: 0.15)) { showStopAllConfirm = true }
            }
            .buttonStyle(.bordered)
            .disabled(monitor.models.isEmpty)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { showQuitConfirm = true }
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .clipShape(Circle())
            .padding(.trailing, -8)
            .help("Quit OllamaDock")
        }
    }
}

private struct StatusIndicator: View {
    let active: Bool
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(active ? Color(nsColor: .systemGreen) : Color(nsColor: .systemGray))
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SectionHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color.secondary.opacity(0.35))
        }
    }
}
