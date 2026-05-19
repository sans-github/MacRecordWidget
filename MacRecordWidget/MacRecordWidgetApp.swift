import SwiftUI
import AppKit

@main
struct MacRecordWidgetApp: App {
    @State private var recordingManager = RecordingManager()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle("Include Video", isOn: $recordingManager.videoEnabled)
                        .toggleStyle(.checkbox)
                        .disabled(recordingManager.isRecording)
                        .accessibilityLabel("Include video in recording")
                        .accessibilityIdentifier("videoModeToggle")
                    Spacer()
                    Button {
                        Task {
                            if recordingManager.isRecording {
                                try? await recordingManager.stopRecording()
                            }
                            NSApplication.shared.terminate(nil)
                        }
                    } label: {
                        Image(systemName: "power")
                    }
                    .buttonStyle(.plain)
                    .help("Quit MacRecordWidget")
                    .accessibilityLabel("Quit MacRecordWidget")
                    .accessibilityIdentifier("quitButton")
                }

                Divider()

                // Pulsing dot: provides in-flight visual feedback while isInFlight is true.
                // Hidden from VoiceOver because the disabled button state already communicates
                // the in-flight condition.
                PulsingDot(isInFlight: recordingManager.isInFlight, isStarting: !recordingManager.isRecording)
                    .frame(height: recordingManager.isInFlight ? 8 : 0)

                VStack(spacing: 8) {
                    Button {
                        Task { await startAndDismiss() }
                    } label: {
                        Label("Start", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                    .disabled(recordingManager.isRecording || recordingManager.isInFlight)
                    .accessibilityLabel("Start recording")
                    .accessibilityIdentifier("startButton")

                    Button {
                        Task { await stopAndDismiss() }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color(NSColor.systemRed))
                    .disabled(!recordingManager.isRecording || recordingManager.isInFlight)
                    .accessibilityLabel("Stop recording")
                    .accessibilityIdentifier("stopButton")
                }
            }
            .padding(16)
            .frame(width: 200)
        } label: {
            let icon = recordingManager.videoEnabled
                ? (recordingManager.isRecording ? "video.fill" : "video")
                : (recordingManager.isRecording ? "mic.fill" : "mic")
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(recordingManager.isRecording ? .green : .primary)
        }
        .menuBarExtraStyle(.window)
    }

    @MainActor
    private func startAndDismiss() async {
        let panel = NSApp.keyWindow
        do {
            try await recordingManager.startRecording()
        } catch {
            presentAlert(for: error)
        }
        // DISMISSAL: Use orderOut(nil) on the captured keyWindow rather than
        // popover.close(). Calling close() while recording is active breaks the
        // double-click-to-reopen behavior (popover enters an inconsistent state).
        // The 100ms delay allows the button animation to complete first.
        // See CLAUDE.md "Gotchas" for full explanation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { panel?.orderOut(nil) }
    }

    @MainActor
    private func stopAndDismiss() async {
        let panel = NSApp.keyWindow
        do {
            try await recordingManager.stopRecording()
        } catch {
            presentAlert(for: error)
        }
        // DISMISSAL: Use orderOut(nil) on the captured keyWindow rather than
        // popover.close(). Calling close() while recording is active breaks the
        // double-click-to-reopen behavior (popover enters an inconsistent state).
        // The 100ms delay allows the button animation to complete first.
        // See CLAUDE.md "Gotchas" for full explanation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { panel?.orderOut(nil) }
    }

    @MainActor
    private func presentAlert(for error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        switch error as? RecordingError {
        case .accessibilityDenied:
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "MacRecordWidget needs Accessibility permission to make Photo Booth full-screen. Open System Settings > Privacy & Security > Accessibility and enable MacRecordWidget."
        case .shortcutLaunchFailed(let reason):
            alert.messageText = "Could Not Start Recording"
            alert.informativeText = "The recording shortcut could not be launched. Make sure a Shortcut named \"Start\" (or \"Stop\") exists in the Shortcuts app. Detail: \(reason)"
        case nil:
            alert.messageText = "Recording Error"
            alert.informativeText = error.localizedDescription
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - PulsingDot

private struct PulsingDot: View {
    let isInFlight: Bool
    let isStarting: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(isStarting ? Color.accentColor : .red)
            .frame(width: 8, height: 8)
            .scaleEffect((!reduceMotion && pulsing) ? 0.7 : 1.0)
            .opacity(isInFlight ? 1 : 0)
            .accessibilityHidden(true)
            .onChange(of: isInFlight) { _, newValue in
                if newValue && !reduceMotion {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        pulsing = true
                    }
                } else {
                    pulsing = false
                }
            }
    }
}
