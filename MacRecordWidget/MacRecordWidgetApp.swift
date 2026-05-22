import SwiftUI
import AppKit

@main
struct MacRecordWidgetApp: App {
    @State private var recordingManager = RecordingManager()

    var body: some Scene {
        MenuBarExtra {
            HStack(spacing: 8) {
                Toggle(isOn: $recordingManager.videoEnabled) {
                    Image(systemName: recordingManager.videoEnabled ? "video.fill" : "video")
                }
                .toggleStyle(.switch)
                .disabled(recordingManager.isRecording)
                .accessibilityLabel("Include video in recording")
                .accessibilityIdentifier("videoModeToggle")

                Spacer()

                Button {
                    Task { await startOnly() }
                } label: {
                    Image(systemName: "record.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .disabled(recordingManager.isRecording || recordingManager.isInFlight)
                .accessibilityLabel("Start recording")
                .accessibilityIdentifier("startButton")

                Button {
                    Task { await stopOnly() }
                } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .disabled(!recordingManager.isRecording || recordingManager.isInFlight)
                .accessibilityLabel("Stop recording")
                .accessibilityIdentifier("stopButton")

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
                .contentShape(Rectangle())
                .help("Quit MacRecordWidget")
                .accessibilityLabel("Quit MacRecordWidget")
                .accessibilityIdentifier("quitButton")
            }
            .padding(12)
            .frame(width: 200)
        } label: {
            MenuBarIcon(isRecording: recordingManager.isRecording)
        }
        .menuBarExtraStyle(.window)
    }

    @MainActor
    private func startOnly() async {
        do {
            try await recordingManager.startRecording()
        } catch {
            presentAlert(for: error)
        }
    }

    @MainActor
    private func stopOnly() async {
        do {
            try await recordingManager.stopRecording()
        } catch {
            presentAlert(for: error)
        }
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

// MARK: - MenuBarIcon

private struct MenuBarIcon: View {
    let isRecording: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blinkOpacity: Double = 1.0

    private let dotColor = Color(red: 1.0, green: 0.620, blue: 0.200)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "record.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isRecording ? .green : .primary)

            if isRecording {
                Circle()
                    .fill(dotColor)
                    .frame(width: 5, height: 5)
                    .opacity(reduceMotion ? 1.0 : blinkOpacity)
                    .offset(x: 2, y: 2)
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: isRecording) { _, recording in
            if recording && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    blinkOpacity = 0.15
                }
            } else {
                blinkOpacity = 1.0
            }
        }
    }
}
