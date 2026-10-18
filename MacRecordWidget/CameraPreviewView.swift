import AVFoundation
import SwiftUI

/// macOS 14 has no SwiftUI-native camera preview, so the live image has to come
/// from an `AVCaptureVideoPreviewLayer` hosted in AppKit.
///
/// The layer is **not** created here. It is owned by `CameraManager` for the
/// app's lifetime, because a preview layer that deallocates takes the session
/// lock on the main thread and can deadlock against the session queue. See the
/// comment on `CameraManager.previewLayer`.
@MainActor
struct CameraPreviewLayerView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        previewLayer.frame = view.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = previewLayer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// The preview block below the button row: either the live image or a message
/// state. Its controls live in the button row, not here.
@MainActor
struct CameraPreviewPanel: View {
    @Bindable var camera: CameraManager
    let playback: PlaybackManager
    let scale: PanelScale

    /// Matches the rounding of the `MenuBarExtra` panel itself. The preview runs
    /// flush to the panel's left, right and bottom edges, so only its bottom
    /// corners are rounded; square ones would poke out past the window.
    private static let panelCornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .underPageBackgroundColor))
            // Mounted unconditionally: unmounting it would deallocate the
            // shared preview layer, which is one half of a main-thread deadlock
            // against the session queue. Message states are drawn over it on an
            // opaque background instead.
            CameraPreviewLayerView(previewLayer: camera.previewLayer)
                .opacity(camera.state == .running ? 1 : 0)
            if camera.state != .running {
                ZStack {
                    Rectangle()
                        .fill(Color(nsColor: .underPageBackgroundColor))
                    messageView
                        .padding(.horizontal, 16)
                }
            }
            // The last video plays over the surface. The camera layer above
            // stays mounted and the session keeps running underneath, so
            // "Live Camera" is instant and the deadlock rules are untouched.
            if playback.isVideoOnSurface {
                VideoPlaybackSurface(playback: playback, scale: scale, isMirrored: camera.isMirrored)
            }
            // Audio leaves the live camera showing and only borrows the
            // bottom edge for a scrubber, in the same place as the video one.
            if playback.phase == .playing(.audio) {
                VStack {
                    Spacer(minLength: 0)
                    PlaybackTransport(playback: playback, showsPause: false)
                }
                .padding(10)
                .foregroundStyle(Color.white)
                .environment(\.colorScheme, .dark)
            }
        }
        .frame(width: scale.previewWidth, height: scale.previewHeight)
        .clipShape(
            .rect(
                bottomLeadingRadius: Self.panelCornerRadius,
                bottomTrailingRadius: Self.panelCornerRadius
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera preview")
        .accessibilityIdentifier("cameraPreview")
    }

    // MARK: - States

    @ViewBuilder
    private var messageView: some View {
        VStack(spacing: 6) {
            if camera.state == .starting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // Restricted deliberately gets no button: the Settings pane cannot
            // resolve an MDM or parental-controls restriction.
            if camera.state == .denied {
                Button("Open Settings") { openCameraSettings() }
                    .font(.system(size: 12))
                    .accessibilityIdentifier("openCameraSettingsButton")
            }
            // The failure state is reachable from the start watchdog, so it has
            // to offer a way back: a spinner that never resolves and no button
            // is the state this bug used to leave the panel in.
            if case .failed = camera.state {
                Button("Try Again") { camera.retry() }
                    .font(.system(size: 12))
                    .accessibilityIdentifier("retryCameraButton")
            }
        }
    }

    private var symbolName: String {
        switch camera.state {
        case .denied, .restricted: "lock.fill"
        case .noCamera: "video.slash"
        case .failed: "exclamationmark.triangle"
        default: "video"
        }
    }

    private var message: String {
        switch camera.state {
        case .idle, .running: ""
        // Held until a real frame arrives, not until startRunning() is
        // dispatched. Camera warm-up is a second or more of nothing, and a
        // silent black rectangle for that long reads as broken.
        case .starting: "Starting camera…"
        case .notDetermined: "Waiting for camera access…"
        case .denied: "Camera access is turned off for MacRecordWidget."
        case .restricted: "Camera access is restricted on this Mac and cannot be changed here."
        case .noCamera: "No camera connected."
        case .failed(let reason): reason
        }
    }

    private func openCameraSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

}

// MARK: - Video playback

/// Hosts `PlaybackManager.playerLayer`. Like the camera preview, the layer is
/// passed in rather than created here, so mounting and unmounting this view
/// never rebuilds it. The layer is a sublayer of a plain backing layer rather
/// than the backing layer itself, because AppKit owns the geometry of a view's
/// backing layer and could reset the mirroring transform.
@MainActor
struct PlayerLayerView: NSViewRepresentable {
    let playerLayer: AVPlayerLayer
    let isMirrored: Bool

    func makeNSView(context: Context) -> PlayerHostView {
        let view = PlayerHostView()
        view.wantsLayer = true
        view.playerLayer = playerLayer
        view.layer?.addSublayer(playerLayer)
        return view
    }

    func updateNSView(_ nsView: PlayerHostView, context: Context) {
        nsView.isMirrored = isMirrored
    }
}

final class PlayerHostView: NSView {
    var playerLayer: AVPlayerLayer?
    var isMirrored = false {
        didSet { if isMirrored != oldValue { needsLayout = true } }
    }

    override func layout() {
        super.layout()
        guard let playerLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // bounds + position, not frame: frame is undefined under a transform.
        playerLayer.bounds = bounds
        playerLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        playerLayer.setAffineTransform(
            isMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        )
        CATransaction.commit()
    }
}

/// The last video on the preview surface: opening, playing/paused, or missing.
/// Overlay controls sit on a dark material so they read the same in light and
/// dark appearance. Drawn the same way round as the preview (the mirror
/// toggle), though the file itself is always unmirrored.
@MainActor
struct VideoPlaybackSurface: View {
    let playback: PlaybackManager
    let scale: PanelScale
    let isMirrored: Bool

    var body: some View {
        ZStack {
            switch playback.phase {
            case .playing:
                Rectangle().fill(Color.black)
                PlayerLayerView(playerLayer: playback.playerLayer, isMirrored: isMirrored)
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        badge
                        Spacer(minLength: 0)
                        Button("Live Camera") { playback.stop() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .modifier(PlaybackOverlayChrome(cornerRadius: 999))
                            .help("Back to the live camera")
                            .accessibilityLabel("Back to live camera")
                            .accessibilityIdentifier("liveCameraButton")
                    }
                    Spacer(minLength: 0)
                    PlaybackTransport(playback: playback, showsPause: true)
                }
                .padding(10)
                .foregroundStyle(Color.white)
                .environment(\.colorScheme, .dark)
            case .videoMissing:
                Rectangle().fill(Color(nsColor: .underPageBackgroundColor))
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                    Text("The last video is no longer in Photo Booth's library. It may have been deleted there.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Back to Live Camera") { playback.stop() }
                        .font(.system(size: 12))
                        .accessibilityIdentifier("backToLiveButton")
                }
                .padding(.horizontal, 16)
                .accessibilityElement(children: .combine)
            default:
                // Opening. Usually too brief to see.
                Rectangle().fill(Color(nsColor: .underPageBackgroundColor))
                VStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Opening the last video…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityIdentifier("videoPlaybackSurface")
    }

    /// "Last video · mirrored" or "Last video · as others see it", naming
    /// whichever way round the mirror toggle is drawing it. Dropped at the small scale, where it would collide with
    /// Live Camera.
    private var badge: some View {
        HStack(spacing: 5) {
            Image(systemName: "play.rectangle.fill")
            Text("Last video")
            if scale != .small {
                Text(isMirrored ? "· mirrored" : "· as others see it")
                    .font(.system(size: 10))
                    .opacity(0.75)
            }
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .padding(.leading, 7)
        .padding(.trailing, 9)
        .padding(.vertical, 3)
        .modifier(PlaybackOverlayChrome(cornerRadius: 999))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isMirrored ? "Playing your last video, mirrored" : "Playing your last video, shown as others see it")
    }
}

/// Play/pause, elapsed, scrubber, duration. Click-only: the app defines no
/// keyboard shortcuts. Shared by both mediums; audio drops the pause button
/// because audio is play/stop only (pause is an open design question).
@MainActor
struct PlaybackTransport: View {
    let playback: PlaybackManager
    let showsPause: Bool

    /// Held while the user drags, so the periodic refresh does not yank the
    /// knob back to the player's position mid-drag.
    @State private var scrubbing: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let total = max(playback.duration, 0.1)
            let position = min(scrubbing ?? playback.currentTime(), total)
            HStack(spacing: 9) {
                if showsPause {
                    Button { playback.togglePause() } label: {
                        // Swaps glyph, unlike the row: QuickTime's convention
                        // applies inside the video.
                        Image(systemName: playback.isPaused ? "play.fill" : "pause.fill")
                            .frame(width: 14)
                    }
                    .buttonStyle(.plain)
                    .help(playback.isPaused ? "Play" : "Pause")
                    .accessibilityLabel(playback.isPaused ? "Play" : "Pause")
                    .accessibilityIdentifier("playPauseButton")
                }
                Text(RecordingManager.formatElapsed(position))
                    .monospacedDigit()
                Slider(
                    value: Binding(
                        get: { position },
                        set: { value in
                            scrubbing = value
                            playback.seek(to: value)
                        }
                    ),
                    in: 0...total,
                    onEditingChanged: { editing in
                        if !editing { scrubbing = nil }
                    }
                )
                .controlSize(.mini)
                .tint(.white)
                .accessibilityLabel("Playback position")
                .accessibilityIdentifier("playbackScrubber")
                Text(RecordingManager.formatElapsed(total))
                    .monospacedDigit()
            }
            .font(.system(size: 11))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .modifier(PlaybackOverlayChrome(cornerRadius: 10))
        }
    }
}

/// Dark material behind every overlay control, plus a 1pt white stroke under
/// Increase Contrast.
struct PlaybackOverlayChrome: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(.regularMaterial, in: shape)
            .overlay(
                shape
                    .stroke(Color.white.opacity(contrast == .increased ? 0.5 : 0.18), lineWidth: contrast == .increased ? 1 : 0.5)
                    .allowsHitTesting(false)
            )
            .contentShape(shape)
    }
}

/// The camera picker, mounted in the button row next to the camera toggle so
/// the two camera controls sit together. Mirroring is not here: it lives in
/// the button row beside the video record button, as a toggle.
@MainActor
struct CameraControls: View {
    let camera: CameraManager
    let scale: PanelScale

    var body: some View {
        HStack(spacing: 8) {
            // A Menu of Buttons, deliberately NOT a `Picker`. A Picker needs a
            // two-way binding, and the only honest source of truth for "which
            // camera is live" is `activeCamera`, which `configure()` updates
            // asynchronously from the session queue. SwiftUI's NSPopUpButton
            // reads that binding back on its next update pass, still sees the
            // previous device, and writes it back as a second `select()` --
            // which switched the camera and then silently switched it back
            // about two seconds later. Buttons are one-way commands: there is
            // no getter to read back and nothing to write back.
            //
            // The label still names the device actually feeding the layer,
            // which after a fallback is not the persisted preference.
            Menu {
                ForEach(camera.availableCameras, id: \.uniqueID) { device in
                    Button {
                        camera.select(deviceID: device.uniqueID)
                    } label: {
                        if device.uniqueID == camera.activeCamera?.uniqueID {
                            Label(device.localizedName, systemImage: "checkmark")
                        } else {
                            Text(device.localizedName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(camera.activeCamera?.localizedName ?? "No camera")
                        .font(scale.controlFont)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    // The chevron sits in a blue well rather than being drawn
                    // by the popup button itself. Blue, the row's colour for a
                    // lit control that is not a recording -- picking a camera
                    // captures nothing.
                    //
                    // This is why the native indicator is hidden and the label
                    // is drawn by hand: an NSPopUpButton's own chevron cannot be
                    // tinted separately from its content.
                    Image(systemName: "chevron.down")
                        .font(scale.chevronFont)
                        .foregroundStyle(RowPalette.glyphOn)
                        .frame(width: scale.chevronWellWidth, height: scale.glyphSize)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(RowPalette.control)
                        )
                }
                .padding(.leading, 7)
                .padding(.trailing, 4)
                .frame(height: scale.controlHeight)
                // The same off-state chrome as every toggle in the row: the
                // menu is never "on", so it is always the outlined rounded
                // rect. Keeping the container matters more here than anywhere
                // else -- without it a menu stops looking like a menu.
                .background(
                    CapsuleControlBackground(
                        scale: scale,
                        isOn: false,
                        tint: RowPalette.control,
                        ember: nil
                    )
                )
                .contentShape(Rectangle())
            }
            // `.button` + `.plain` + a hidden indicator, so what is drawn is
            // exactly the label above and nothing else. It is still a Menu of
            // Buttons underneath -- see the comment above; it must not become a
            // Picker.
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .font(scale.controlFont)
            .controlSize(scale.controlSize)
            .frame(maxWidth: scale.pickerMaxWidth)
            .disabled(camera.availableCameras.isEmpty)
            .accessibilityLabel("Preview camera")
            .accessibilityIdentifier("cameraPicker")

        }
    }
}
