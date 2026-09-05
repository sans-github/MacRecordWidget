import SwiftUI
import AppKit

// Explicit @MainActor: Swift 5.9 (Xcode 15.2, which CI uses) does not infer it
// on App, so the @State initializers below would be nonisolated without it.
@main
@MainActor
struct MacRecordWidgetApp: App {
    @State private var recordingManager = RecordingManager()
    @State private var camera = CameraManager()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var measuredSize: CGSize = .zero

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 20) {
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
                .help("Show camera preview")
                .accessibilityLabel("Show camera preview")
                .accessibilityIdentifier("videoModeToggle")

                // Audio group: a bordered box holding the transport controls,
                // with the label riding the leading edge like a fieldset legend.
                HStack(spacing: 10) {
                    Button {
                        Task { await startOnly() }
                    } label: {
                        Image(systemName: "record.circle.fill")
                            .font(Self.glyphFont)
                            .foregroundStyle(.red)
                            .frame(width: Self.glyphSize, height: Self.glyphSize)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .disabled(recordingManager.isRecording || recordingManager.isInFlight)
                    .help("Start audio recording")
                    .accessibilityLabel("Start recording")
                    .accessibilityIdentifier("startButton")

                    Button {
                        Task { await stopOnly() }
                    } label: {
                        Image(systemName: "square")
                            .font(Self.glyphFont)
                            .frame(width: Self.glyphSize, height: Self.glyphSize)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .disabled(!recordingManager.isRecording || recordingManager.isInFlight)
                    .help("Stop audio recording")
                    .accessibilityLabel("Stop recording")
                    .accessibilityIdentifier("stopButton")
                }
                // Leading inset leaves room for the label to sit on the border.
                .padding(.leading, 46)
                .padding(.trailing, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .overlay(alignment: .leading) {
                    Text("Audio")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                // Opaque so it masks the border it sits on.
                                .fill(Color(nsColor: .windowBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                        .offset(x: -10)
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 12)

                if recordingManager.videoEnabled {
                    CameraControls(camera: camera)
                }

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
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help("Quit MacRecordWidget")
                .accessibilityLabel("Quit MacRecordWidget")
                .accessibilityIdentifier("quitButton")
            }
            .focusEffectDisabled()
            // Trailing-aligned so the row stays put as the panel grows leftward.
            // Without an explicit alignment the row centers and slides 152pt.
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
            .background(PanelSizer(size: measuredSize, animated: !reduceMotion))
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
    private static let glyphFont = Font.system(size: 13, weight: .regular)

    /// Fixed at the preview width in both states. A panel that changes width
    /// has to be repositioned as well as resized, and AppKit shows the move
    /// before the correction lands, which reads as the panel jumping from the
    /// centre to the right. Holding the width constant means only the height
    /// ever changes, so the trailing edge never moves.
    private var contentWidth: CGFloat { CameraPreviewPanel.previewWidth }

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
