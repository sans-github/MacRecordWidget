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
                // Blue: the pin acts on the window, not on a recording or on
                // the camera.
                .toggleStyle(CapsuleToggleStyle(scale: scale, tint: RowPalette.window))
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
                    // camera toggle beside it. It also survives the 11pt small
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
                        .opacity(recordingManager.isArming ? 0.35 : 1)
                }
                // Red capsule, and while it is genuinely capturing it wears
                // the red Live Ember instead of the flat fill. `isRecording`,
                // not "recording or arming": the ember means "you are being
                // captured", which during arming is not yet true.
                .toggleStyle(
                    CapsuleToggleStyle(
                        scale: scale,
                        tint: RowPalette.audio,
                        ember: recordingManager.isRecording ? .audio : nil
                    )
                )
                // Sits on the button's bottom-right corner, offset outward so
                // most of it falls on the panel background rather than on the
                // red fill underneath, where amber on red would barely read.
                .overlay(alignment: .bottomTrailing) {
                    if recordingManager.isRecording {
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

                RecordingTimer(manager: recordingManager, scale: scale)

                // Video sits inside the mic+timer group, not out with the
                // camera settings: it is a record button sharing that timer,
                // and grouping it with the picker would file it as a preview
                // control, which is what it used to be and no longer is.
                //
                // Same glyph in both states and the same corner dot as the
                // mic. The hue differs because the medium does.
                Toggle(isOn: videoRecordingBinding) {
                    Image(systemName: "video.fill")
                        .font(scale.glyphFont)
                        .frame(width: scale.glyphSize, height: scale.glyphSize)
                        .opacity(isArmingVideo ? 0.35 : 1)
                }
                // Green, not red: green is the camera's hue throughout the
                // row. Same ember treatment as the mic, same 3.4s period, its
                // own hue.
                .toggleStyle(
                    CapsuleToggleStyle(
                        scale: scale,
                        tint: RowPalette.video,
                        ember: recordingManager.isRecordingVideo ? .video : nil
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
                // Green, the camera hue, because it acts on the preview. It
                // therefore looks identical to the video button while both are
                // on, and the glyph is the only thing separating them -- an
                // accepted consequence of hue meaning "which subsystem" rather
                // than "which control".
                .toggleStyle(CapsuleToggleStyle(scale: scale, tint: RowPalette.video))
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

                // Three toggle buttons rather than a segmented Picker.
                // `.pickerStyle(.segmented)` is an NSSegmentedControl, which
                // ignores SwiftUI's `.font()`, so its labels stayed 13pt while
                // everything around them grew. These use the same pattern as
                // the rest of the row, so they scale with it.
                //
                // This sizes the *preview* only. It has never had any bearing
                // on the recorded video, which uses the camera's own format.
                HStack(spacing: 2) {
                    ForEach(PanelScale.allCases) { option in
                        Toggle(isOn: scaleBinding(for: option)) {
                            Text(option.label)
                                .font(scale.scaleLabelFont)
                                .frame(width: scale.glyphSize, height: scale.glyphSize)
                        }
                        // Green: these size the preview.
                        .toggleStyle(CapsuleToggleStyle(scale: scale, tint: RowPalette.video))
                        .help("\(option.helpLabel) preview")
                        .accessibilityLabel("\(option.helpLabel) preview size")
                    }
                }
                .accessibilityIdentifier("panelScalePicker")

                Button {
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
                        tint: RowPalette.window,
                        ember: nil,
                        isOn: true
                    )
                )
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
            // Top and bottom separately: the bottom gap meets the hard top
            // edge of the preview image and the top gap meets empty window
            // chrome, so equal numbers read bottom-heavy.
            .padding(.top, scale.verticalPaddingTop)
            .padding(.bottom, scale.verticalPaddingBottom)

            // Always mounted. The preview is the app's resting state now:
            // there is no toggle, and nothing to collapse.
            CameraPreviewPanel(camera: camera, scale: scale)
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
            .task {
                recordingManager.onError = { error in presentAlert(for: error) }
                await camera.start()
            }
            // `pause()`, not a teardown: the session stays configured so the
            // next open skips device discovery and format negotiation. It also
            // refuses to stop while a movie is being written, which is what
            // lets a video recording survive the panel closing.
            .onDisappear { camera.pause() }
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
        if recordingManager.isArming { return "Starting… wait to speak" }
        return recordingManager.isRecording
            ? "Stop and save to Voice Memos"
            : "Record audio to Voice Memos"
    }

    /// Drives the single audio control: on starts, off stops.
    ///
    /// Deliberately reads `isRecording`, not "recording or arming": the red
    /// fill is the "you are being captured" signal, and showing it while Voice
    /// Memos is still coming up would be the same lie the arming state exists
    /// to remove. The button is disabled during arming, so it cannot be clicked
    /// twice while it looks off.
    private var recordingBinding: Binding<Bool> {
        Binding(
            get: { recordingManager.isRecording },
            set: { shouldRecord in
                Task { shouldRecord ? await startOnly() : await stopOnly() }
            }
        )
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
        if recordingManager.isRecordingVideo { return "Stop and save to Photo Booth" }
        if recordingManager.medium == .audio { return "Stop the audio recording first" }
        if let reason = camera.videoUnavailableReason { return reason }
        return "Record video to Photo Booth"
    }

    /// Names the result rather than the state: the button's fill already says
    /// which way round the preview is.
    private var mirrorHelp: String {
        camera.isMirrored
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
            alert.informativeText = "Video recordings include sound, so MacRecordWidget needs microphone access. Turn it on in System Settings › Privacy & Security › Microphone."
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

// MARK: - RecordingTimer

/// MM:SS beside the audio button. 00:00 at launch, counting while recording,
/// and holding the last duration after stop until the next recording starts.
///
/// While recording the value comes from a `TimelineView` driven off the start
/// date, so there is no timer to invalidate and nothing ticking while the panel
/// is closed. Reopening the panel recomputes from the wall clock, which is also
/// why a long recording cannot drift.
@MainActor
struct RecordingTimer: View {
    let manager: RecordingManager
    let scale: PanelScale

    var body: some View {
        Group {
            if let startedAt = manager.startedAt {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    label(manager.elapsed(asOf: context.date))
                }
            } else {
                label(manager.lastElapsed)
            }
        }
        .accessibilityLabel("Recording time")
        .accessibilityIdentifier("recordingTimer")
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
            // Semantic styles, so both light and dark mode are handled: full
            // strength while the number means "now", faded once it is history.
            .foregroundStyle(manager.isRecording ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .opacity(manager.isRecording ? 1 : 0.65)
            .padding(.horizontal, scale.timerPaddingH)
            // The height is the row's, not the text's. Every control holds one
            // cap height in every state, and the timer is the one item here
            // that is not a button, so it has to be told.
            .frame(height: scale.controlHeight)
            // Same 1pt separatorColor border as every control in the row, so
            // the readout reads as part of the same family.
            .overlay(
                RoundedRectangle(cornerRadius: scale.cornerRadius, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    .allowsHitTesting(false)
            )
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
private struct MenuBarIcon: View {
    let isRecording: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "record.circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isRecording ? .green : .primary)

            if isRecording {
                RecordingDot(diameter: 5)
                    .offset(x: 2, y: 2)
            }
        }
    }
}

// MARK: - Row palette

/// The semantic capsule colours, chosen 2026-09-24 (design option B).
///
/// Hue carries meaning here rather than selection: red is audio capture, green
/// is everything that belongs to the camera (video capture, mirror, the three
/// preview sizes, the camera menu's chevron), blue is everything that acts on
/// the window itself (pin, quit). One consequence, accepted: the user's own
/// accent colour is no longer honoured anywhere in the row.
///
/// ⚠️ The white glyph on `video` green is a known, measured, *accepted*
/// contrast failure. White on #3AD862 is 1.88:1 against the 3:1 that WCAG
/// 1.4.11 asks of a control's icon, and both ember gradients drop further at
/// their bright point (green to 1.41:1). The alternatives were a black glyph on
/// green only (11.18:1, but then the row has two glyph colours and stops
/// reading as one family) or darkening the green to #10913A (4.09:1, but it is
/// then no longer the FaceTime green that was being matched). The user was
/// shown all three with the numbers and chose to keep white, to match the
/// FaceTime look. **Do not helpfully "fix" this.** If it is ever revisited it
/// is a design decision, not a bug fix.
enum RowPalette {
    /// #FF383C. Audio capture. Sits between systemRed's light (#FF3B30) and
    /// dark (#FF453A) values, so one number covers both appearances.
    static let audio = Color(red: 1.0, green: 0.2196, blue: 0.2353)

    /// #3AD862. Everything camera: video capture, mirror, S/M/L, the chevron
    /// well. Already lighter than systemGreen in either appearance, so it is
    /// deliberately not darkened for dark mode.
    static let video = Color(red: 0.2275, green: 0.8471, blue: 0.3843)

    /// #007AFF. Everything window: the pin and the quit button. This is
    /// systemBlue's *light* value used in both appearances, so the dark panel
    /// gets a slightly heavier blue than macOS would pick.
    static let window = Color(red: 0.0, green: 0.4784, blue: 1.0)

    /// The glyph on any lit capsule. See the contrast note above.
    static let glyphOn = Color.white
}

// MARK: - Live Ember

/// The drifting gradient a capture control wears while it is actually
/// recording, in its own hue.
///
/// Two channels, both on a 3.4s period: the gradient's axis sweeps across the
/// capsule, and a coloured glow breathes just outside it. 3.4s is deliberately
/// not a near-match to `RecordingDot`'s 1.6s blink -- two indicators at almost
/// the same rhythm read as a rendering fault, while two at obviously different
/// rhythms read as two indicators.
enum EmberHue {
    case audio
    case video

    /// What the gradient collapses to when it cannot animate.
    var flat: Color {
        switch self {
        case .audio: RowPalette.audio
        case .video: RowPalette.video
        }
    }

    /// Dark end, mid, bright end. The dark mode variants lift the dark stop and
    /// warm the bright one, because the same gradient on a dark panel reads
    /// muddier than it does on a light one.
    func stops(dark: Bool) -> [Color] {
        switch (self, dark) {
        case (.audio, false):
            [Color(red: 0.7216, green: 0.0824, blue: 0.0588), // #B8150F
             RowPalette.audio,
             Color(red: 1.0, green: 0.4784, blue: 0.2392)]    // #FF7A3D
        case (.audio, true):
            [Color(red: 0.5569, green: 0.1059, blue: 0.0706), // #8E1B12
             RowPalette.audio,
             Color(red: 1.0, green: 0.6235, blue: 0.2706)]    // #FF9F45
        case (.video, false):
            [Color(red: 0.0549, green: 0.4196, blue: 0.1725), // #0E6B2C
             RowPalette.video,
             Color(red: 0.5490, green: 0.9412, blue: 0.4784)] // #8CF07A
        case (.video, true):
            [Color(red: 0.0431, green: 0.3451, blue: 0.1412), // #0B5824
             RowPalette.video,
             Color(red: 0.6118, green: 0.9608, blue: 0.5412)] // #9CF58A
        }
    }

    /// The breathing glow outside the capsule.
    var glow: Color {
        switch self {
        case .audio: Color(red: 1.0, green: 0.3529, blue: 0.2353)
        case .video: Color(red: 0.4706, green: 0.9412, blue: 0.5098)
        }
    }
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
            .padding(.horizontal, scale.controlPaddingH(isOn: isOn))
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

/// Used directly by the quit button, which has no off state, and indirectly by
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
