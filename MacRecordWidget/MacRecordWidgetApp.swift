import SwiftUI
import AppKit

// Explicit @MainActor: Swift 5.9 (Xcode 15.2, which CI uses) does not infer it
// on App, so the @State initializers below would be nonisolated without it.
@main
@MainActor
struct MacRecordWidgetApp: App {
    @State private var recordingManager = RecordingManager()
    @State private var camera = CameraManager()
    @State private var measuredSize: CGSize = .zero

    /// Whether the panel stays on screen when another app is clicked.
    /// Persisted, because it is a working preference rather than a per-session
    /// mode: someone who wants the panel to stay put wants that every launch.
    @AppStorage("panelPinned") private var isPinned = false

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 14) {
                // One control, not two: record and stop were always mutually
                // exclusive with one of them disabled, so a single toggle
                // carries the same state with half the controls.
                Text("Audio")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Toggle(isOn: recordingBinding) {
                    Image(systemName: recordingManager.isRecording ? "stop.fill" : "record.circle.fill")
                        .font(Self.glyphFont)
                        .frame(width: Self.glyphSize, height: Self.glyphSize)
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .tint(.red)
                .overlay(Self.controlOutline)
                .disabled(recordingManager.isInFlight)
                .help(recordingManager.isRecording ? "Stop audio recording" : "Start audio recording")
                .accessibilityLabel(recordingManager.isRecording ? "Stop recording" : "Start recording")
                .accessibilityIdentifier("recordToggle")

                Spacer(minLength: 12)

                // An icon toggle button rather than a switch: a switch is a wide
                // capsule sitting next to round glyphs, so no amount of sizing
                // makes it read as part of the same family.
                Toggle(isOn: $recordingManager.videoEnabled) {
                    Image(systemName: "video.fill")
                        .font(Self.glyphFont)
                        .frame(width: Self.glyphSize, height: Self.glyphSize)
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .overlay(Self.controlOutline)
                .help("Show camera preview")
                .accessibilityLabel("Show camera preview")
                .accessibilityIdentifier("videoModeToggle")

                if recordingManager.videoEnabled {
                    CameraControls(camera: camera)
                }

                Toggle(isOn: $isPinned) {
                    Image(systemName: isPinned ? "pin.fill" : "pin.slash")
                        .font(Self.glyphFont)
                        .frame(width: Self.glyphSize, height: Self.glyphSize)
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .overlay(Self.controlOutline)
                .help(isPinned ? "Panel stays open when you click another app" : "Panel closes when you click another app")
                .accessibilityLabel("Keep panel open")
                .accessibilityIdentifier("pinToggle")

                Button {
                    Task {
                        if recordingManager.isRecording {
                            try? await recordingManager.stopRecording()
                        }
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "power")
                        .font(Self.glyphFont)
                        .frame(width: Self.glyphSize, height: Self.glyphSize)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .overlay(Self.controlOutline)
                .help("Quit MacRecordWidget")
                .accessibilityLabel("Quit MacRecordWidget")
                .accessibilityIdentifier("quitButton")
            }
            .focusEffectDisabled()
            // Leading-aligned: the panel is a fixed width, so the row fills it
            // and each group sits at its own end. Without an explicit alignment
            // an HStack centers inside its frame.
            .frame(maxWidth: .infinity, alignment: .leading)

            if recordingManager.videoEnabled {
                CameraPreviewPanel(camera: camera)
                    .transition(.opacity)
            }
            }
            .frame(width: contentWidth, alignment: .trailing)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .fixedSize()
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: PanelSizeKey.self, value: proxy.size)
                }
            )
            .background(PanelSizer(size: measuredSize, isPinned: isPinned))
            .onPreferenceChange(PanelSizeKey.self) { measuredSize = $0 }
            .task(id: recordingManager.videoEnabled) {
                if recordingManager.videoEnabled {
                    await camera.start()
                } else {
                    camera.stop()
                }
            }
            .onDisappear { camera.stop() }
        } label: {
            MenuBarIcon(isRecording: recordingManager.isRecording)
        }
        .menuBarExtraStyle(.window)
    }

    /// One glyph size and weight for every control in the row, so they read as
    /// a single family rather than assorted symbols.
    private static let glyphSize: CGFloat = 16

    /// A constant boundary on every control. Without it a toggle only shows an
    /// edge when it is on, so an off toggle and an on toggle read as two
    /// different kinds of object rather than one control in two states.
    private static var controlOutline: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            .allowsHitTesting(false)
    }
    private static let glyphFont = Font.system(size: 13, weight: .regular)

    /// Fixed at the preview width in both states. A panel that changes width
    /// has to be repositioned as well as resized, and AppKit shows the move
    /// before the correction lands, which reads as the panel jumping from the
    /// centre to the right. Holding the width constant means only the height
    /// ever changes, so the trailing edge never moves.
    private var contentWidth: CGFloat { CameraPreviewPanel.previewWidth }

    /// Drives the single audio control: on starts, off stops.
    private var recordingBinding: Binding<Bool> {
        Binding(
            get: { recordingManager.isRecording },
            set: { shouldRecord in
                Task { shouldRecord ? await startOnly() : await stopOnly() }
            }
        )
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

@MainActor
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
