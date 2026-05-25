import SwiftUI

struct PopoverView: View {
    @Bindable var monitor: ModelMonitor
    @State private var showQuitDaemonConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
            if let error = monitor.lastUnloadError
                            ?? monitor.lastLoadError
                            ?? monitor.lastDaemonError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            footer
        }
        .padding(12)
        .frame(width: 340)
        .onAppear {
            monitor.startTicking()
            monitor.clearActionErrors()
        }
        .onDisappear { monitor.stopTicking() }
        .confirmationDialog(
            "Quit the Ollama daemon?",
            isPresented: $showQuitDaemonConfirm,
            titleVisibility: .visible
        ) {
            Button("Quit Ollama", role: .destructive) {
                Task { await monitor.quitDaemon() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Running models will be unloaded.")
        }
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
                Task { await monitor.unloadAll() }
            }
            .buttonStyle(.bordered)
            .disabled(monitor.models.isEmpty)

            Button("Quit Ollama") {
                showQuitDaemonConfirm = true
            }
            .buttonStyle(.bordered)
            .disabled(!monitor.daemonUp)
            .help("Quit the Ollama daemon")

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
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
