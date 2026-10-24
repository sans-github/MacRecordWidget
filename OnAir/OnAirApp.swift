import os
import SwiftUI
import AppKit

// Explicit @MainActor: Swift 5.9 (Xcode 15.2, which CI uses) does not infer it
// on App.
@main
@MainActor
struct OnAirApp: App {
    /// Declared first: the managers read their settings in their own
    /// initialisers, which run later in `applicationDidFinishLaunching`.
    private let defaultsMigrated: Void = migrateDefaultsFromMacRecordWidget()

    /// Owns the menu bar item and the panel. See `PanelController`.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// The panel is not a SwiftUI scene (see `PanelController`), but an `App`
    /// needs one. A never-inserted `MenuBarExtra`: no icon, no window. Not a
    /// `Settings` scene, which macOS 27 opened as an empty window at every
    /// launch (observed 2026-10-24).
    var body: some Scene {
        MenuBarExtra("OnAir", isInserted: .constant(false)) { EmptyView() }
    }
}

/// Everything inside the panel: the button row and the camera preview. Hosted
/// by `PanelController` for the app's lifetime, so opening and closing the
/// panel are the controller's calls, not this view's appear and disappear.
@MainActor
struct PanelView: View {
    let recordingManager: RecordingManager
    let camera: CameraManager
    let playback: PlaybackManager
    @State private var measuredSize: CGSize = .zero

    /// Whether the panel stays on screen when another app is clicked.
    /// Persisted, because it is a working preference rather than a per-session
    /// mode: someone who wants the panel to stay put wants that every launch.
    @AppStorage("panelPinned") private var isPinned = false

    /// Panel size, persisted. Stored as the raw string because `@AppStorage`
    /// cannot hold an enum directly.
    @AppStorage("panelScale") private var scaleRaw = PanelScale.medium.rawValue

    var body: some View {
        // spacing: 0 and no padding on this stack. The row carries its own
        // padding; the preview is meant to touch the panel's edges.
        VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: scale.rowSpacing) {
            Toggle(isOn: $isPinned) {
                Image(systemName: isPinned ? "pin.fill" : "pin.slash")
                    .font(scale.glyphFont)
                    .frame(width: scale.glyphSize, height: scale.glyphSize)
            }
            // Blue: the pin acts on the window, not on a recording or on
            // the camera.
            .toggleStyle(CapsuleToggleStyle(scale: scale, tint: RowPalette.control))
            .help(isPinned ? "Let panel close on its own" : "Keep panel open")
            .accessibilityLabel("Keep panel open")
            .accessibilityIdentifier("pinToggle")

            // The mic and its readout are one unit, so they sit closer to
            // each other than to the rest of the row. Half the row spacing,
            // which still clears the recording dot on the button's corner.
            HStack(spacing: scale.rowSpacing / 2) {
            // One control, not two: record and stop were always mutually
            // exclusive with one of them disabled, so a single toggle
            // carries the same state with half the controls.
            Toggle(isOn: recordingBinding) {
                // A microphone, not a record dot: a red disc is the generic
                // record mark and reads as video as readily as audio. The
                // mic names the medium, and pairs with `video.fill` on the
                // video record toggle beside it. It also survives the 11pt small
                // scale, which the thinner audio symbols do not.
                //
                // One glyph in both states, like the camera toggle: only
                // the fill flips. Swapping the glyph to `stop.fill` made
                // this control behave unlike every other toggle in the row.
                Image(systemName: "mic.fill")
                    .font(scale.glyphFont)
                    .frame(width: scale.glyphSize, height: scale.glyphSize)
                    // Dimmed while Voice Memos is still coming up. The red
                    // fill, the blinking dot and the timer all arrive
                    // together a moment later, which is the "speak now"
                    // signal.
                    .opacity(isArmingAudio ? 0.35 : 1)
            }
            // Red capsule, and while it is genuinely capturing it wears
            // the red Live Ember instead of the flat fill. `isRecordingAudio`,
            // not "recording or arming": the ember means "you are being
            // captured", which during arming is not yet true.
            .toggleStyle(
                CapsuleToggleStyle(
                    scale: scale,
                    tint: RowPalette.capture,
                    ember: recordingManager.isRecordingAudio ? .capture : nil
                )
            )
            // Sits on the button's bottom-right corner, offset outward so
            // most of it falls on the panel background rather than on the
            // red fill underneath, where amber on red would barely read.
            .overlay(alignment: .bottomTrailing) {
                if recordingManager.isRecordingAudio {
                    RecordingDot(diameter: scale.recordingDotSize)
                        .offset(
                            x: scale.recordingDotSize * 0.45,
                            y: scale.recordingDotSize * 0.45
                        )
                }
            }
            // Also disabled while video holds the medium: the two are
            // mutually exclusive, so one clock always has one meaning.
            .disabled(
                recordingManager.isInFlight
                || recordingManager.isArming
                || recordingManager.medium == .video
            )
            .help(armingAwareHelp)
            .accessibilityLabel(armingAwareHelp)
            .accessibilityIdentifier("recordToggle")

            // Play last, merged into the timer box: the box already shows
            // the last recording's length, so pressing it plays that
            // recording. The glyph names the medium it will play. Like the
            // record toggles it keeps its glyph and flips its fill (blue,
            // nothing is being captured); it never swaps to a stop glyph.
            Button {
                if playback.isActive { playback.stop() } else { playback.play() }
            } label: {
                PlayLastLabel(
                    manager: recordingManager,
                    playback: playback,
                    scale: scale,
                    glyph: playGlyph
                )
            }
            .buttonStyle(PlayLastButtonStyle(scale: scale, isOn: playback.isPlaying))
            .overlay {
                if playback.isPlaying {
                    PlaybackProgressLine(playback: playback)
                        .clipShape(Capsule())
                        .allowsHitTesting(false)
                }
            }
            // Browsing and deleting live in a context menu so the row
            // keeps its width. Previous/Next walk every Photo Booth movie
            // and Voice Memos memo by creation date.
            .contextMenu {
                Button("Play Last Recording") { playback.play() }
                    .disabled(playback.isActive)
                Divider()
                Button("Previous Recording") { playback.step(-1) }
                    .disabled(playback.isActive || !playback.canStepBack)
                Button("Next Recording") { playback.step(1) }
                    .disabled(playback.isActive || !playback.canStepForward)
                Divider()
                Button("Move to Trash…") { confirmTrash(playback) }
                    .disabled(playback.lastRecording?.url == nil)
            }
            // Disabled while either medium arms or records: recording and
            // playback never run together. Record during playback is the
            // other direction, handled in the record bindings.
            .disabled(
                playback.lastRecording == nil
                || recordingManager.isBusy
                || recordingManager.isInFlight
            )
            .help(playHelp)
            .accessibilityLabel(playAccessibilityLabel)
            .accessibilityAddTraits(
                recordingManager.isRecording || playback.isPlaying ? .updatesFrequently : []
            )
            .accessibilityIdentifier("playLastButton")

            // Video sits inside the mic+timer group, not out with the
            // camera settings: it is a record button sharing that timer,
            // and grouping it with the picker would file it as a preview
            // control, which is what it used to be and no longer is.
            //
            // Same glyph in both states and the same corner dot as the
            // mic. The hue is the same red: it says "you are being recorded",
            // and the glyph already names the medium.
            Toggle(isOn: videoRecordingBinding) {
                Image(systemName: "video.fill")
                    .font(scale.glyphFont)
                    .frame(width: scale.glyphSize, height: scale.glyphSize)
                    .opacity(isArmingVideo ? 0.35 : 1)
            }
            // Red, the same as the mic: the hue reports a live recording
            // rather than which subsystem the button belongs to, so both
            // record controls light and ember identically.
            .toggleStyle(
                CapsuleToggleStyle(
                    scale: scale,
                    tint: RowPalette.capture,
                    ember: recordingManager.isRecordingVideo ? .capture : nil
                )
            )
            .overlay(alignment: .bottomTrailing) {
                if recordingManager.isRecordingVideo {
                    RecordingDot(diameter: scale.recordingDotSize)
                        .offset(
                            x: scale.recordingDotSize * 0.45,
                            y: scale.recordingDotSize * 0.45
                        )
                }
            }
            .disabled(isVideoButtonDisabled)
            .help(videoHelp)
            .accessibilityLabel(videoHelp)
            .accessibilityIdentifier("videoRecordToggle")
            }

            // Sits immediately right of the video button, but outside the
            // record group, at full row spacing rather than the group's
            // half spacing. It acts on the preview, not on a recording, so
            // filing it inside the mic+timer+video unit would say it shares
            // that timer, which it does not.
            //
            // Preview only: `CameraManager` pins the movie output
            // unmirrored, so this can never change what lands on disk. That
            // is why it has no disabled state -- it is free to flip as often
            // as the user likes, mid-recording included.
            Toggle(isOn: mirrorBinding) {
                // Apple's own Flip Horizontal glyph, the one Preview and
                // Photos use for this exact operation. Checked at 11pt: the
                // two triangles and the arrow above them stay distinct at
                // the small scale.
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    .font(scale.glyphFont)
                    .frame(width: scale.glyphSize, height: scale.glyphSize)
            }
            // Blue, like every lit control that is not a recording. It
            // acts on the preview, nothing is being captured because of
            // it, and red here would claim otherwise.
            .toggleStyle(CapsuleToggleStyle(scale: scale, tint: RowPalette.control))
            // Stays live during video playback: playback is drawn the
            // same way round as the preview. The file itself is pinned
            // unmirrored, so this never touches what was recorded.
            .help(mirrorHelp)
            .accessibilityLabel(mirrorHelp)
            .accessibilityIdentifier("mirrorToggle")

            Spacer(minLength: 12)

            // The preview is permanent now, so these are permanent too.
            // They used to be mounted only with the preview, which stranded
            // an oversized row whenever the camera was turned off at the
            // large scale, with no visible control to shrink it.
            CameraControls(camera: camera, scale: scale)
                // Switching camera reconfigures the session, which would
                // truncate a movie mid-write.
                .disabled(recordingManager.isRecordingVideo)

            // Zoom out / zoom in step through the five sizes in order and
            // disable at either end. Plain buttons, not toggles: neither
            // has an on state, so both are drawn as off capsules.
            //
            // This sizes the *preview* only. It has never had any bearing
            // on the recorded video, which uses the camera's own format.
            HStack(spacing: 2) {
                zoomButton(to: scale.smaller, symbol: "minus.magnifyingglass", title: "Zoom Out", shortcut: "⌘−")
                zoomButton(to: scale.larger, symbol: "plus.magnifyingglass", title: "Zoom In", shortcut: "⌘+")
            }
            .accessibilityIdentifier("panelZoom")

            // Close and Quit as one pair, 2pt apart like the zoom pair:
            // the two ways of leaving. Close is a plain off capsule, since
            // it has no on state; Quit stays the permanent blue capsule.
            HStack(spacing: 2) {
                Button {
                    PanelSizer.closePanel()
                } label: {
                    Image(systemName: "xmark")
                        .font(scale.glyphFont)
                        .frame(width: scale.glyphSize, height: scale.glyphSize)
                }
                .buttonStyle(
                    CapsuleControlButtonStyle(
                        scale: scale,
                        tint: RowPalette.control,
                        ember: nil,
                        isOn: false
                    )
                )
                .help("Close panel (⌘W)")
                .accessibilityLabel("Close panel")
                .accessibilityIdentifier("closePanelButton")

                Button {
                    quit()
                } label: {
                    Image(systemName: "power")
                        .font(scale.glyphFont)
                        .frame(width: scale.glyphSize, height: scale.glyphSize)
                }
                // A permanent blue capsule: quit acts on the window, and
                // unlike every other control here it has no off state, so it is
                // always drawn lit.
                .buttonStyle(
                    CapsuleControlButtonStyle(
                        scale: scale,
                        tint: RowPalette.control,
                        ember: nil,
                        isOn: true
                    )
                )
                .help("Quit (⌘Q)")
                .accessibilityLabel("Quit OnAir")
                .accessibilityIdentifier("quitButton")
            }
        }
        .focusEffectDisabled()
        // Leading-aligned: the panel is a fixed width, so the row fills it
        // and each group sits at its own end. Without an explicit alignment
        // an HStack centers inside its frame.
        .frame(maxWidth: .infinity, alignment: .leading)
        // Padding is on the row, not on the panel, so the preview below can
        // run flush to the left, right and bottom edges.
        .padding(.horizontal, scale.horizontalPadding)
        // Top and bottom separately: the bottom gap meets the hard top
        // edge of the preview image and the top gap meets empty window
        // chrome, so equal numbers read bottom-heavy.
        .padding(.top, scale.verticalPaddingTop)
        .padding(.bottom, scale.verticalPaddingBottom)

        // Always mounted. The preview is the app's resting state now:
        // there is no toggle, and nothing to collapse.
        CameraPreviewPanel(camera: camera, playback: playback, scale: scale)
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
        // Starting or stopping audio runs a Shortcut, which brings
        // Shortcuts or Voice Memos forward and takes key from the panel,
        // so ⌘. would go nowhere. Take it back, but only from them.
        .onChange(of: recordingManager.isArming) { Self.reclaimFocusFromRecorder() }
        .onChange(of: recordingManager.isRecording) { Self.reclaimFocusFromRecorder() }
        .task {
            recordingManager.onError = { error in presentAlert(for: error) }
            let playback = self.playback
            recordingManager.onFinished = { finished in playback.recordingFinished(finished) }
            playback.onAudioUnavailable = { presentPlaybackAlert() }
            installKeyMonitor()
        }
    }

    /// The chosen size. Every dimension in the panel derives from it, so the
    /// row and the preview grow together rather than drifting apart.
    private var scale: PanelScale { PanelScale(rawValue: scaleRaw) ?? .medium }

    // MARK: - Keyboard shortcuts

    /// Installed once for the app's lifetime.
    private static var keyMonitor: Any?

    /// ⌘= / ⌘+ zoom in, ⌘− zooms out, ⌘R starts audio, ⇧⌘R starts video,
    /// ⌘. or Esc stops whichever is recording, Space plays or stops the last
    /// recording as the timer box does, ⌘Q quits as the Quit button does, ⌘W closes the panel (a recording
    /// carries on: audio lives in Voice Memos, and `pause()` refuses to stop
    /// the session mid-video).
    ///
    /// A local key monitor, not `.keyboardShortcut`. The SwiftUI shortcuts on
    /// the zoom buttons stuck between two sizes on hardware (2026-10-23): the
    /// registered action evidently kept a target computed at an older render.
    /// Here everything is read when the key is pressed: the scale from
    /// `UserDefaults` (which `@AppStorage` observes), recording state from the
    /// managers themselves. The app is `LSUIElement`, so keys reach it only
    /// while the panel is key; nothing here is a global hotkey.
    ///
    /// Start keys never stop and the stop key never starts, so a mistimed
    /// press cannot start a second recording or end one meant to begin. Each
    /// guard repeats the matching button's disabled rule.
    private func installKeyMonitor() {
        guard Self.keyMonitor == nil else { return }
        let manager = recordingManager, camera = camera, playback = playback
        let app = self
        Self.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Leave alerts alone: ⌘. is Cancel there.
            guard NSApp.modalWindow == nil else { return event }
            let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
            @MainActor func stopRecording() {
                guard !manager.isInFlight, !manager.isArming else { return }
                if manager.isRecordingAudio {
                    Task {
                        do { try await manager.stopRecording() }
                        catch { app.presentAlert(for: error) }
                    }
                } else if manager.isRecordingVideo {
                    Task { await manager.stopVideoRecording(camera: camera) }
                }
            }
            // Esc (53) stops a recording like ⌘., and passes through otherwise.
            if flags.isEmpty, event.keyCode == 53 {
                guard manager.isRecording else { return event }
                stopRecording()
                return nil
            }
            // Space plays the last recording, then pauses and resumes it.
            // keyCode 49 is Space on every layout.
            if flags.isEmpty, event.keyCode == 49 {
                guard playback.lastRecording != nil, !manager.isBusy, !manager.isInFlight else { return nil }
                // An opening or missing state is dismissed rather than paused.
                if playback.isPlaying {
                    playback.togglePause()
                } else if playback.isActive {
                    playback.stop()
                } else {
                    playback.play()
                }
                return nil
            }
            // Left and right arrows (123, 124) jump 10s while a recording plays.
            if flags.isEmpty, event.keyCode == 123 || event.keyCode == 124 {
                guard playback.isPlaying else { return event }
                playback.skip(by: event.keyCode == 123 ? -10 : 10)
                return nil
            }
            guard flags.contains(.command), !flags.contains(.option), !flags.contains(.control),
                  let key = event.charactersIgnoringModifiers?.lowercased() else { return event }
            let shift = flags.contains(.shift)
            switch key {
            case "=", "+":
                Self.zoom(larger: true)
            case "-" where !shift:
                Self.zoom(larger: false)
            case "r":
                guard manager.medium == nil, !manager.isInFlight else { return nil }
                if shift {
                    guard camera.canRecordVideo else { return nil }
                    Task {
                        playback.stop()
                        do { try await manager.startVideoRecording(camera: camera) }
                        catch { app.presentAlert(for: error) }
                    }
                } else {
                    Task {
                        playback.stop()
                        do { try await manager.startRecording() }
                        catch { app.presentAlert(for: error) }
                    }
                }
            case "q" where !shift:
                app.quit()
            case "w" where !shift:
                PanelSizer.closePanel()
            case "." where !shift:
                stopRecording()
            default:
                return event
            }
            return nil
        }
    }

    /// Hands key back to the panel if Shortcuts or Voice Memos took it.
    ///
    /// Checked twice, because the Shortcut's apps come forward on their own
    /// schedule after the URL opens. Only those two are ever displaced: if the
    /// user has moved to any other app in the meantime, focus stays there, and
    /// a closed panel is never reopened.
    private static func reclaimFocusFromRecorder() {
        for delay in [0.3, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                MainActor.assumeIsolated {
                    guard let window = PanelSizer.panelWindow, window.isVisible, !window.isKeyWindow else { return }
                    let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none"
                    // Logged so a miss can be traced to the app that took key.
                    Logger(subsystem: "com.onair", category: "panel")
                        .notice("panel not key after \(delay, privacy: .public)s; frontmost \(front, privacy: .public)")
                    guard ["com.apple.shortcuts", "com.apple.VoiceMemos"].contains(front) else { return }
                    NSApp.activate()
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }

    private static func zoom(larger: Bool) {
        let defaults = UserDefaults.standard
        let current = PanelScale(rawValue: defaults.string(forKey: "panelScale") ?? "") ?? .medium
        if let next = larger ? current.larger : current.smaller {
            defaults.set(next.rawValue, forKey: "panelScale")
        }
    }

    /// Shared by the Quit button and ⌘Q.
    private func quit() {
        Task {
            // Await finalisation rather than terminating straight
            // away: AVCaptureMovieFileOutput closes its file
            // asynchronously, and a process that dies first leaves
            // an unplayable .mov behind.
            switch recordingManager.medium {
            case .video:
                await recordingManager.stopVideoRecording(camera: camera)
            case .audio:
                try? await recordingManager.stopRecording()
            case nil:
                break
            }
            NSApplication.shared.terminate(nil)
        }
    }

    /// One zoom step. `target` is nil at the end of the range, which disables
    /// the button rather than hiding it, so the row does not shift.
    private func zoomButton(to target: PanelScale?, symbol: String, title: String, shortcut: String) -> some View {
        Button {
            if let target { scaleRaw = target.rawValue }
        } label: {
            Image(systemName: symbol)
                .font(scale.glyphFont)
                .frame(width: scale.glyphSize, height: scale.glyphSize)
        }
        .buttonStyle(
            CapsuleControlButtonStyle(
                scale: scale,
                tint: RowPalette.control,
                ember: nil,
                isOn: false
            )
        )
        .disabled(target == nil)
        .help(target.map { "\(title) to \($0.helpLabel) (\(shortcut))" } ?? title)
        .accessibilityLabel(title)
        .accessibilityValue("\(scale.helpLabel) preview")
    }

    /// The preview width for the chosen scale, in both states, so toggling the
    /// camera only ever changes the panel's height. The width does change when
    /// the scale changes, which is fine: the panel is right-anchored, so only
    /// the left edge moves, and `PanelSizer` suppresses painting until the
    /// corrected frame is in place.
    private var contentWidth: CGFloat { scale.previewWidth }

    /// Says what the button will do, and during arming says why it is waiting.
    /// VoiceOver gets the same string: "starting" is exactly what a screen
    /// reader user needs to hear before they start talking.
    private var armingAwareHelp: String {
        if isArmingAudio { return "Starting… wait to speak" }
        return recordingManager.isRecordingAudio
            ? "Stop and save to Voice Memos (⌘.)"
            : "Record audio to Voice Memos (⌘R)"
    }

    /// Drives the single audio control: on starts, off stops.
    ///
    /// Deliberately reads `isRecordingAudio`, not "recording or arming", and not
    /// plain `isRecording`, which is also true during a video recording: the red
    /// fill is the "you are being captured" signal, and showing it while Voice
    /// Memos is still coming up would be the same lie the arming state exists
    /// to remove. The button is disabled during arming, so it cannot be clicked
    /// twice while it looks off.
    private var recordingBinding: Binding<Bool> {
        Binding(
            get: { recordingManager.isRecordingAudio },
            set: { shouldRecord in
                Task {
                    if shouldRecord {
                        // Record wins over playback: stop it, then arm.
                        playback.stop()
                        await startOnly()
                    } else {
                        await stopOnly()
                    }
                }
            }
        )
    }

    /// True only while the *audio* button is arming, so the mic does not dim
    /// during a video start.
    private var isArmingAudio: Bool {
        recordingManager.isArming && recordingManager.medium == .audio
    }

    /// True only while the *video* button is arming, so the mic button does
    /// not dim in sympathy during a video start.
    private var isArmingVideo: Bool {
        recordingManager.isArming && recordingManager.medium == .video
    }

    private var isVideoButtonDisabled: Bool {
        if recordingManager.medium == .video {
            // Already ours: only the arming window and an in-flight call block
            // the press, exactly as on the mic side.
            return recordingManager.isInFlight || recordingManager.isArming
        }
        // Otherwise it needs a free medium and a camera that is genuinely
        // delivering frames. Pressing during warm-up would start a recording
        // whose first moments are dead.
        return recordingManager.isInFlight
            || recordingManager.medium != nil
            || !camera.canRecordVideo
    }

    /// Says what the button will do, or why it cannot. The unavailable reasons
    /// come from `CameraManager`, so the tooltip and the message in the preview
    /// area cannot disagree about what is wrong.
    private var videoHelp: String {
        if isArmingVideo { return "Starting… wait to perform" }
        if recordingManager.isRecordingVideo { return "Stop and save to Photo Booth (⌘.)" }
        if recordingManager.medium == .audio { return "Stop the audio recording first" }
        if let reason = camera.videoUnavailableReason { return reason }
        return "Record video to Photo Booth (⇧⌘R)"
    }

    /// Names the result rather than the state: the button's fill already says
    /// which way round the preview is.
    private var mirrorHelp: String {
        return camera.isMirrored
            ? "Show the preview as others see it"
            : "Mirror the preview"
    }

    /// Drives the mirror control. Recording is never mirrored either way, so
    /// there is no guard here.
    private var mirrorBinding: Binding<Bool> {
        Binding(
            get: { camera.isMirrored },
            set: { camera.setMirrored($0) }
        )
    }

    /// Drives the video control: on starts, off stops.
    ///
    /// Reads `isRecordingVideo` rather than "recording or arming", for the same
    /// reason the mic binding does: the red fill means "you are being
    /// captured", and during arming that is not yet true.
    private var videoRecordingBinding: Binding<Bool> {
        Binding(
            get: { recordingManager.isRecordingVideo },
            set: { shouldRecord in
                Task {
                    if shouldRecord {
                        // Stopping first returns the surface to the live
                        // camera, so arming is never drawn over the old video.
                        playback.stop()
                        do {
                            try await recordingManager.startVideoRecording(camera: camera)
                        } catch {
                            presentAlert(for: error)
                        }
                    } else {
                        await recordingManager.stopVideoRecording(camera: camera)
                    }
                }
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

    // MARK: - Play last

    /// Names the medium the press will play. `play.fill` (disabled) before
    /// anything has been recorded.
    private var playGlyph: String {
        switch playback.lastRecording?.medium {
        case .audio: "waveform"
        case .video: "play.rectangle.fill"
        case nil: "play.fill"
        }
    }

    private var playHelp: String {
        guard let last = playback.lastRecording else { return "No recording yet" }
        if recordingManager.isBusy { return "Recording time" }
        if playback.isOpening { return "Opening the last recording…" }
        if playback.isActive {
            return last.medium == .video ? "Back to the live camera (Space)" : "Stop playing (Space)"
        }
        let length = RecordingManager.formatElapsed(last.duration)
        return last.medium == .audio
            ? "Play last voice recording (\(length)) (Space)"
            : "Play last video recording (\(length)) (Space)"
    }

    /// Spoken form names the medium, so VoiceOver users are not left guessing
    /// what the waveform means.
    private var playAccessibilityLabel: String {
        guard let last = playback.lastRecording else { return "No recording yet" }
        if recordingManager.isBusy { return "Recording time" }
        let medium = last.medium == .audio ? "audio" : "video"
        if playback.isActive { return "Stop playing the last \(medium)" }
        return "Play your last recording, \(medium), \(Self.spokenDuration(last.duration))"
    }

    private static func spokenDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: seconds.rounded(.down)) ?? RecordingManager.formatElapsed(seconds)
    }

    /// The audio file could not be found or opened. Informational, not
    /// critical: nothing failed to capture.
    @MainActor
    private func presentPlaybackAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Can't Play the Last Recording"
        alert.informativeText = "OnAir couldn't open the recording in Voice Memos. It may still be saving, it may have been deleted, or macOS may be blocking access to Voice Memos' files."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Open Voice Memos")
        guard alert.runModal() == .alertSecondButtonReturn,
              let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.VoiceMemos")
        else { return }
        // Leaves Voice Memos running; the next Start quits it first anyway.
        NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
    }

    @MainActor
    private func presentAlert(for error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        switch error {
        case RecordingError.shortcutLaunchFailed(let reason):
            alert.messageText = "Could Not Start Recording"
            alert.informativeText = "The recording shortcut could not be launched. Make sure a Shortcut named \"Start\" (or \"Stop\") exists in the Shortcuts app. Detail: \(reason)"
        case VideoRecordingError.microphoneDenied:
            alert.messageText = "Microphone Access Needed"
            alert.informativeText = "Video recordings include sound, so OnAir needs microphone access. Turn it on in System Settings › Privacy & Security › Microphone."
        case let videoError as VideoRecordingError:
            alert.messageText = "Could Not Record Video"
            alert.informativeText = videoError.localizedDescription
        default:
            alert.messageText = "Recording Error"
            alert.informativeText = error.localizedDescription
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Play last

/// MM:SS inside the play-last control. 00:00 at launch with nothing recorded,
/// the live clock while recording, the playback position while playing, and
/// otherwise the last recording's length, faded.
///
/// While recording the value comes from a `TimelineView` driven off the start
/// date, so there is no timer to invalidate and nothing ticking while the panel
/// is closed. Reopening the panel recomputes from the wall clock, which is also
/// why a long recording cannot drift. The box itself is drawn by
/// `PlayLastButtonStyle`.
@MainActor
struct RecordingTimer: View {
    let manager: RecordingManager
    let playback: PlaybackManager
    let scale: PanelScale

    var body: some View {
        Group {
            if let startedAt = manager.startedAt {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    label(manager.elapsed(asOf: context.date))
                }
            } else if playback.isPlaying {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    label(playback.currentTime())
                }
            } else {
                // The persisted recording's length when there is one, so a
                // relaunch does not show 00:00 beside an enabled play control.
                label(playback.lastRecording?.duration ?? manager.lastElapsed)
            }
        }
        .accessibilityIdentifier("recordingTimer")
    }

    /// Full strength while the number means "now" (recording or playing),
    /// faded once it is history.
    private var isLive: Bool { manager.isRecording || playback.isPlaying }

    private var foreground: AnyShapeStyle {
        if playback.isPlaying { return AnyShapeStyle(RowPalette.glyphOn) }
        if manager.isRecording { return AnyShapeStyle(.primary) }
        return AnyShapeStyle(.secondary)
    }

    private func label(_ interval: TimeInterval) -> some View {
        Text(RecordingManager.formatElapsed(interval))
            .font(scale.controlFont)
            // Without this the digits are proportionally spaced and the row
            // twitches every second as the glyph widths change.
            .monospacedDigit()
            // MM:SS is one word and must never wrap. At the small scale the row
            // is tight enough that SwiftUI would otherwise break it across two
            // lines mid-value, which is what "00:0 / 1" was.
            .lineLimit(1)
            .fixedSize()
            // Semantic styles while off, so light and dark are both handled;
            // white on the blue capsule while playing.
            .foregroundStyle(foreground)
            .opacity(isLive ? 1 : 0.65)
    }
}

/// Medium glyph + timer. A separate view so it can read `isEnabled`: when the
/// control is disabled only the glyph dims, and the digits keep reading as the
/// recording clock.
@MainActor
struct PlayLastLabel: View {
    let manager: RecordingManager
    let playback: PlaybackManager
    let scale: PanelScale
    let glyph: String

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        // The glyph sits as far from the digits as from the capsule's edge.
        HStack(spacing: scale.controlPaddingH) {
            Image(systemName: glyph)
                .font(scale.glyphFont)
                .frame(width: scale.glyphSize, height: scale.glyphSize)
                // Dimmed while opening, the same treatment as arming.
                .opacity(!isEnabled || playback.isOpening ? 0.35 : 1)
            RecordingTimer(manager: manager, playback: playback, scale: scale)
        }
    }
}

/// The play-last control's box. Like `CapsuleControlChrome`, except that it
/// does not dim as a whole when disabled (see `PlayLastLabel`), and it uses
/// the timer's padding, because it *is* the timer box.
struct PlayLastButtonStyle: ButtonStyle {
    let scale: PanelScale
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isOn ? RowPalette.glyphOn : Color(nsColor: .labelColor))
            .padding(.horizontal, scale.timerPaddingH)
            // The height is the row's, so this control holds one cap height in
            // every state, like every other control.
            .frame(height: scale.controlHeight)
            .background(
                CapsuleControlBackground(scale: scale, isOn: isOn, tint: RowPalette.control, ember: nil)
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// 2pt progress line along the bottom of the lit play control. It moves with
/// time and carries information, so it stays under Reduce Motion.
@MainActor
struct PlaybackProgressLine: View {
    let playback: PlaybackManager

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let total = playback.duration
            let fraction = total > 0 ? min(1, playback.currentTime() / total) : 0
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.3))
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .scaleEffect(x: fraction, y: 1, anchor: .leading)
            }
            .frame(height: 2)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - RecordingDot

/// The blinking amber "recording" dot, shared by the menu bar icon and the
/// audio button so the two indicators cannot drift apart in colour or rhythm.
///
/// Mount it only while recording: the blink starts in `onAppear`, so its
/// lifetime *is* the recording state and there is no separate flag to keep in
/// sync. Under Reduce Motion it holds steady rather than disappearing, since it
/// is the indicator, not decoration.
@MainActor
struct RecordingDot: View {
    let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity: Double = 1.0

    static let color = Color(red: 1.0, green: 0.620, blue: 0.200)

    var body: some View {
        Circle()
            .fill(Self.color)
            .frame(width: diameter, height: diameter)
            .opacity(reduceMotion ? 1.0 : opacity)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    opacity = 0.15
                }
            }
            // The toggle already announces recording state; a second
            // announcement for the dot would just be noise.
            .accessibilityHidden(true)
    }
}

// MARK: - MenuBarIcon

@MainActor
struct MenuBarIcon: View {
    let isRecording: Bool

    /// Outer size of the capsule. `PanelController` sizes the status item
    /// from it.
    static let size = CGSize(width: 34, height: 18)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // A red capsule with white glyphs, after FaceTime's green one in
            // the menu bar: colour, not a template image, so it reads the same
            // in light and dark menu bars. Recording shows only through the
            // amber dot, since the capsule is already red.
            HStack(spacing: 3) {
                Image(systemName: "mic.fill")
                Image(systemName: "video.fill")
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(RowPalette.glyphOn)
            .frame(width: Self.size.width, height: Self.size.height)
            .background(Capsule().fill(RowPalette.capture))

            if isRecording {
                RecordingDot(diameter: 5)
                    .offset(x: 1, y: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Row palette

/// The semantic capsule colours, chosen 2026-09-24 (design option B) and
/// narrowed to two hues on 2026-09-28.
///
/// Hue says whether the app is *capturing*, not which subsystem a control
/// belongs to. Red is a recording in progress, audio or video alike; blue is
/// every other lit control in the row -- pin, mirror, S/M/L, the camera menu's
/// chevron well, quit. The camera green that mirror, S/M/L and the chevron
/// used to wear is gone: it read as a third, unexplained state sitting beside
/// the blue controls, and the subsystem it encoded is not something the user
/// has to act on. One consequence, unchanged: the user's own accent colour is
/// not honoured anywhere in the row.
///
/// Contrast, computed rather than eyeballed: white on #FF383C is 3.57:1 and
/// white on #007AFF is 4.02:1, both clearing the 3:1 that WCAG 1.4.11 asks of
/// a control's icon. That is a change from the green, which was a known,
/// accepted 1.88:1 failure. The one place still under 3:1 is the *bright point*
/// of the ember gradient (#FF7A3D, 2.59:1), which was already true of the audio
/// ember before this change and lasts a fraction of a second per sweep.
enum RowPalette {
    /// #FF383C. A live recording, audio or video. Sits between systemRed's
    /// light (#FF3B30) and dark (#FF453A) values, so one number covers both
    /// appearances.
    static let capture = Color(red: 1.0, green: 0.2196, blue: 0.2353)

    /// #007AFF. Every lit control that is not a recording: pin, mirror, S/M/L,
    /// the chevron well, quit. This is systemBlue's *light* value used in both
    /// appearances, so the dark panel gets a slightly heavier blue than macOS
    /// would pick.
    static let control = Color(red: 0.0, green: 0.4784, blue: 1.0)

    /// The glyph on any lit capsule. See the contrast note above.
    static let glyphOn = Color.white
}

// MARK: - Live Ember

/// The drifting gradient a capture control wears while it is actually
/// recording.
///
/// Two channels, both on a 3.4s period: the gradient's axis sweeps across the
/// capsule, and a coloured glow breathes just outside it. 3.4s is deliberately
/// not a near-match to `RecordingDot`'s 1.6s blink -- two indicators at almost
/// the same rhythm read as a rendering fault, while two at obviously different
/// rhythms read as two indicators.
///
/// One case, not two. The mic and the video button wear the *same* ember in the
/// same red: what the animation reports is "this app is recording you", and the
/// medium is already said by the glyph, the timer and which capsule is lit.
/// The two mediums are mutually exclusive, so two embers can never be on screen
/// at once to be told apart anyway.
enum EmberHue {
    case capture

    /// What the gradient collapses to when it cannot animate.
    var flat: Color { RowPalette.capture }

    /// Dark end, mid, bright end. The dark mode variant lifts the dark stop and
    /// warms the bright one, because the same gradient on a dark panel reads
    /// muddier than it does on a light one.
    func stops(dark: Bool) -> [Color] {
        if dark {
            return [Color(red: 0.5569, green: 0.1059, blue: 0.0706), // #8E1B12
                    RowPalette.capture,
                    Color(red: 1.0, green: 0.6235, blue: 0.2706)]    // #FF9F45
        } else {
            return [Color(red: 0.7216, green: 0.0824, blue: 0.0588), // #B8150F
                    RowPalette.capture,
                    Color(red: 1.0, green: 0.4784, blue: 0.2392)]    // #FF7A3D
        }
    }

    /// The breathing glow outside the capsule.
    var glow: Color { Color(red: 1.0, green: 0.3529, blue: 0.2353) }
}

/// The ember fill itself.
///
/// Driven by `TimelineView(.animation)` rather than a `repeatForever`
/// animation, for the same reason `RecordingTimer` is: there is no animation to
/// start, own or invalidate, so the phase cannot be left running after the
/// recording stops, and it recomputes correctly when the panel is reopened.
///
/// It falls back to the flat fill under two separate conditions, checked
/// independently: Reduce Motion (the same `accessibilityReduceMotion` that
/// `RecordingDot` already reads -- one mechanism, not two) and Increase
/// Contrast, where a moving gradient is exactly the wrong thing to draw.
struct EmberCapsule: View {
    let hue: EmberHue

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    /// Seconds for one full there-and-back sweep.
    private static let period: Double = 3.4

    var body: some View {
        if reduceMotion || contrast == .increased {
            Capsule().fill(hue.flat)
        } else {
            TimelineView(.animation) { context in
                let phase = Self.phase(at: context.date)
                let ramp = hue.stops(dark: colorScheme == .dark)
                // Symmetric five-stop ramp -- dark, hue, bright, hue, dark --
                // so the sweep has no visible seam where it turns around.
                let colors = [ramp[0], ramp[1], ramp[2], ramp[1], ramp[0]]
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: UnitPoint(x: -0.4 + 1.4 * phase, y: 0),
                            endPoint: UnitPoint(x: 0.6 + 1.4 * phase, y: 1)
                        )
                    )
                    // The glow is a shadow rather than a stroke, so it sits
                    // outside the capsule and never eats into the glyph's
                    // already-marginal contrast against the fill.
                    .shadow(
                        color: hue.glow.opacity(0.55 * phase),
                        radius: 4 + 3 * phase
                    )
            }
        }
    }

    /// 0 → 1 → 0 across one period, eased, so the sweep and the glow turn
    /// around smoothly instead of snapping back at the seam.
    private static func phase(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period) / period
        return (1 - cos(2 * .pi * t)) / 2
    }
}

// MARK: - Capsule controls

/// The background every control in the row wears, in both states.
///
/// Off: the scale's corner radius, `controlBackgroundColor`, and the constant
/// 1pt `separatorColor` outline, which is what makes the resting row read as
/// one family of nine identical objects.
///
/// On: fully round, filled with the control's semantic hue, and *no* outline --
/// the fill is the edge. This is a real discontinuity: an on control changes
/// silhouette as well as colour. The one thing holding the row together across
/// it is that the height never changes, which is why `PanelScale.controlHeight`
/// is applied to every control rather than left to its content.
struct CapsuleControlBackground: View {
    let scale: PanelScale
    let isOn: Bool
    let tint: Color
    /// Non-nil only while this control is the live capture.
    let ember: EmberHue?

    var body: some View {
        if isOn {
            if let ember {
                EmberCapsule(hue: ember)
            } else {
                Capsule().fill(tint)
            }
        } else {
            RoundedRectangle(cornerRadius: scale.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: scale.cornerRadius, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
    }
}

/// The chrome shared by every button and toggle in the row.
///
/// A `View` rather than more code inside the `ButtonStyle`, because a
/// `ButtonStyle` cannot read the environment and the disabled dimming has to
/// come from `isEnabled` -- the native bordered style used to supply that for
/// free.
private struct CapsuleControlChrome<Label: View>: View {
    let scale: PanelScale
    let isOn: Bool
    let tint: Color
    let ember: EmberHue?
    let isPressed: Bool
    let label: Label

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        label
            .foregroundStyle(isOn ? RowPalette.glyphOn : Color(nsColor: .labelColor))
            .padding(.horizontal, scale.controlPaddingH)
            .frame(height: scale.controlHeight)
            .background(
                CapsuleControlBackground(scale: scale, isOn: isOn, tint: tint, ember: ember)
            )
            // The background is a shape, so without this only the drawn pixels
            // would be clickable in the off state's rounded corners.
            .contentShape(Rectangle())
            .opacity(isPressed ? 0.75 : 1)
            .opacity(isEnabled ? 1 : 0.35)
    }
}

/// Used directly by the quit button (always on) and the zoom buttons (always
/// off), and indirectly by
/// every toggle through `CapsuleToggleStyle`.
struct CapsuleControlButtonStyle: ButtonStyle {
    let scale: PanelScale
    let tint: Color
    var ember: EmberHue? = nil
    /// The quit button passes `true`: it is a permanent capsule.
    var isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        CapsuleControlChrome(
            scale: scale,
            isOn: isOn,
            tint: tint,
            ember: ember,
            isPressed: configuration.isPressed,
            label: configuration.label
        )
    }
}

/// Replaces `.toggleStyle(.button)` on every toggle in the row.
///
/// The native bordered style cannot draw a fully round on state, and its
/// background geometry comes from the label's own symbol metrics rather than
/// from the glyph frame, which is what made the pin taller than its siblings.
/// Both problems go away once the background is an explicit shape on an
/// explicit height.
struct CapsuleToggleStyle: ToggleStyle {
    let scale: PanelScale
    let tint: Color
    var ember: EmberHue? = nil

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
        }
        // A custom style means a Button underneath, which does not carry the
        // toggle's own state to VoiceOver the way `.button` did. `.isSelected`
        // is the macOS-native way to say "this one is on" and needs no string,
        // so it cannot drift from the `.help` text the way a second label would.
        .accessibilityAddTraits(configuration.isOn ? [.isSelected] : [])
        .buttonStyle(
            CapsuleControlButtonStyle(
                scale: scale,
                tint: tint,
                ember: ember,
                isOn: configuration.isOn
            )
        )
    }
}

/// The app was called MacRecordWidget until 2026-10-24, and its settings live
/// under that bundle ID. Copied once, never overwriting a value already set,
/// so the pin, the zoom, the camera and the queued Photo Booth index edits
/// survive the rename.
private func migrateDefaultsFromMacRecordWidget() {
    let defaults = UserDefaults.standard
    let doneKey = "migratedFromMacRecordWidget"
    guard !defaults.bool(forKey: doneKey) else { return }
    let old = defaults.persistentDomain(forName: "com.example.MacRecordWidget") ?? [:]
    for (key, value) in old where defaults.object(forKey: key) == nil {
        defaults.set(value, forKey: key)
    }
    defaults.set(true, forKey: doneKey)
}
