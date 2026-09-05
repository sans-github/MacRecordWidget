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

    /// Panel size, persisted. Stored as the raw string because `@AppStorage`
    /// cannot hold an enum directly.
    @AppStorage("panelScale") private var scaleRaw = PanelScale.medium.rawValue

    var body: some Scene {
        MenuBarExtra {
            // spacing: 0 and no padding on this stack. The row carries its own
            // padding; the preview is meant to touch the panel's edges.
            VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: scale.rowSpacing) {
                Toggle(isOn: $isPinned) {
                    Image(systemName: isPinned ? "pin.fill" : "pin.slash")
                        .font(scale.glyphFont)
                        .frame(width: scale.glyphSize, height: scale.glyphSize)
                }
                .toggleStyle(.button)
                .controlSize(scale.controlSize)
                .overlay(controlOutline)
                .help(isPinned ? "Let panel close on its own" : "Keep panel open")
                .accessibilityLabel("Keep panel open")
                .accessibilityIdentifier("pinToggle")

                // One control, not two: record and stop were always mutually
                // exclusive with one of them disabled, so a single toggle
                // carries the same state with half the controls.
                Toggle(isOn: recordingBinding) {
                    // Red while idle, so the control that starts a recording is
                    // the one thing in the row that draws the eye. While
                    // recording the button fills red and the glyph is left to
                    // the button style, which renders it legibly on that fill.
                    Group {
                        if recordingManager.isRecording {
                            Image(systemName: "stop.fill")
                        } else {
                            Image(systemName: "record.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(scale.glyphFont)
                    .frame(width: scale.glyphSize, height: scale.glyphSize)
                }
                .toggleStyle(.button)
                .controlSize(scale.controlSize)
                .tint(.red)
                .overlay(controlOutline)
                .disabled(recordingManager.isInFlight)
                .help(recordingManager.isRecording ? "Stop and save to Voice Memos" : "Record audio to Voice Memos")
                .accessibilityLabel(recordingManager.isRecording ? "Stop recording" : "Start recording")
                .accessibilityIdentifier("recordToggle")

                Spacer(minLength: 12)

                // An icon toggle button rather than a switch: a switch is a wide
                // capsule sitting next to round glyphs, so no amount of sizing
                // makes it read as part of the same family.
                Toggle(isOn: $recordingManager.videoEnabled) {
                    Image(systemName: "video.fill")
                        .font(scale.glyphFont)
                        .frame(width: scale.glyphSize, height: scale.glyphSize)
                }
                .toggleStyle(.button)
                .controlSize(scale.controlSize)
                .overlay(controlOutline)
                .help(recordingManager.videoEnabled ? "Hide camera preview" : "Show camera preview")
                .accessibilityLabel(recordingManager.videoEnabled ? "Hide camera preview" : "Show camera preview")
                .accessibilityIdentifier("videoModeToggle")

                if recordingManager.videoEnabled {
                    CameraControls(camera: camera, scale: scale)

                    // Sits with the camera picker, and only while the preview is
                    // open: the size it changes is mostly the size of the
                    // preview, so it has nothing to act on otherwise.
                    // Three toggle buttons rather than a segmented Picker.
                    // `.pickerStyle(.segmented)` is an NSSegmentedControl,
                    // which ignores SwiftUI's `.font()`, so its labels stayed
                    //13pt while everything around them grew. These use the same
                    // pattern as the rest of the row, so they scale with it.
                    HStack(spacing: 2) {
                        ForEach(PanelScale.allCases) { option in
                            Toggle(isOn: scaleBinding(for: option)) {
                                Text(option.label)
                                    .font(scale.controlFont)
                                    .frame(width: scale.glyphSize, height: scale.glyphSize)
                            }
                            .toggleStyle(.button)
                            .controlSize(scale.controlSize)
                            .overlay(controlOutline)
                            .help("\(option.helpLabel) panel")
                            .accessibilityLabel("\(option.helpLabel) panel size")
                        }
                    }
                    .accessibilityIdentifier("panelScalePicker")
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
                        .font(scale.glyphFont)
                        .frame(width: scale.glyphSize, height: scale.glyphSize)
                }
                .buttonStyle(.bordered)
                .controlSize(scale.controlSize)
                .overlay(controlOutline)
                .help("Quit")
                .accessibilityLabel("Quit MacRecordWidget")
                .accessibilityIdentifier("quitButton")
            }
            .focusEffectDisabled()
            // Leading-aligned: the panel is a fixed width, so the row fills it
            // and each group sits at its own end. Without an explicit alignment
            // an HStack centers inside its frame.
            .frame(maxWidth: .infinity, alignment: .leading)
            // Padding is on the row, not on the panel, so the preview below can
            // run flush to the left, right and bottom edges.
            .padding(.horizontal, scale.horizontalPadding)
            .padding(.vertical, scale.verticalPadding)

            if recordingManager.videoEnabled {
                CameraPreviewPanel(camera: camera, scale: scale)
                    .transition(.opacity)
            }
            }
            .frame(width: contentWidth)
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

    /// The chosen size. Every dimension in the panel derives from it, so the
    /// row and the preview grow together rather than drifting apart.
    private var scale: PanelScale { PanelScale(rawValue: scaleRaw) ?? .medium }

    /// One binding per size button. Turning a button on selects that size;
    /// turning the selected one off is ignored, since a panel always has a size.
    private func scaleBinding(for option: PanelScale) -> Binding<Bool> {
        Binding(
            get: { scale == option },
            set: { isOn in if isOn { scaleRaw = option.rawValue } }
        )
    }

    /// A constant boundary on every control. Without it a toggle only shows an
    /// edge when it is on, so an off toggle and an on toggle read as two
    /// different kinds of object rather than one control in two states.
    private var controlOutline: some View {
        RoundedRectangle(cornerRadius: scale.cornerRadius, style: .continuous)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            .allowsHitTesting(false)
    }

    /// The preview width for the chosen scale, in both states, so toggling the
    /// camera only ever changes the panel's height. The width does change when
    /// the scale changes, which is fine: the panel is right-anchored, so only
    /// the left edge moves, and `PanelSizer` suppresses painting until the
    /// corrected frame is in place.
    private var contentWidth: CGFloat { scale.previewWidth }

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
