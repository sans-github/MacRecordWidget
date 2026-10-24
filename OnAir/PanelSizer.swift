import AppKit
import Carbon.HIToolbox
import os
import SwiftUI


/// Reports the measured size of the popover content.
struct PanelSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// An `NSView` that reports the moment it is attached to a window.
///
/// `updateNSView` is not a reliable hook for this: it runs only when SwiftUI
/// re-renders, and on first appearance the view has no window yet, so a frame
/// applied there is silently dropped and never retried.
final class PanelAnchorView: NSView {
    var onAttach: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            onAttach?(window)
        } else {
        }
    }
}

/// Pins the panel to the right of the screen and keeps it sized to its content.
///
/// The panel's window does not size itself (`PanelController` turns the
/// hosting view's sizing off), so this applies the measured content size,
/// right-anchored and keeping the top edge. Size and origin are applied with
/// screen updates suppressed and flushed once, so no intermediate frame is
/// painted. Do not animate the resize.
struct PanelSizer: NSViewRepresentable {
    let size: CGSize

    /// When true the panel is kept on screen after it loses key status, so
    /// clicking another app no longer folds it away.
    let isPinned: Bool

    /// Gap between the panel's trailing edge and the right of the screen.
    /// Zero: the panel sits flush against the edge.
    fileprivate static let screenMargin: CGFloat = 0

    /// The panel's window once it has opened, for code outside the view tree
    /// that needs to hand key status back to it. Weak: AppKit owns it.
    static weak var panelWindow: NSWindow?

    /// Closes the panel as ⌘W and the close button ask, pinned or not.
    static func closePanel() {
        PanelController.shared?.hide()
    }

    /// Pinned, the app behaves like a regular app: it gets a Dock icon and a
    /// place in ⌘Tab. Unpinned it is back to an accessory (`LSUIElement`).
    static func applyActivationPolicy(pinned: Bool) {
        let policy: NSApplication.ActivationPolicy = pinned ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }

    final class Coordinator {
        var size: CGSize = .zero
        var isPinned = false {
            didSet { if isPinned != oldValue { applyPinnedBehaviour() } }
        }
        /// The panel's unpinned level, restored on unpin. Pinned,
        /// the panel drops to `.normal` so other apps' windows (and ⌘Tab) can
        /// cover it; at its own level it floats over everything.
        private var floatingLevel: NSWindow.Level?
        private var tokens: [NSObjectProtocol] = []
        private weak var window: NSWindow?
        private var isApplying = false

        func attach(to window: NSWindow) {
            guard self.window !== window else {
                align()
                return
            }
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens.removeAll()
            self.window = window
            PanelSizer.panelWindow = window

            let center = NotificationCenter.default
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
                tokens.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.align() }
                })
            }
            tokens.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sendBackIfPinned() }
            })
            tokens.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.bringForwardIfPinned() }
            })
            floatingLevel = window.level
            applyPinnedBehaviour()
            align()
        }

        func applyPinnedBehaviour() {
            PanelSizer.applyActivationPolicy(pinned: isPinned)
            guard let window, let floatingLevel else { return }
            let level = isPinned ? .normal : floatingLevel
            if window.level != level { window.level = level }
        }

        /// Another app took over (⌘Tab, a click, Spotlight): stay on screen
        /// but behind it, like any app window.
        private func sendBackIfPinned() {
            guard isPinned, let window, window.isVisible else { return }
            window.orderBack(nil)
        }

        /// ⌘Tab (or the Dock icon) back to the app brings the panel forward.
        /// Only a panel still on screen: one closed with ⌘W stays closed.
        private func bringForwardIfPinned() {
            guard isPinned, let window, window.isVisible else { return }
            window.makeKeyAndOrderFront(nil)
        }

        func align() {
            // Our own setFrame triggers didMove/didResize; ignore the echo.
            guard !isApplying, let window, size.width > 0, size.height > 0 else { return }
            let current = window.frame
            let screen = window.screen ?? NSScreen.main
            let rightEdge = screen.map { $0.visibleFrame.maxX - PanelSizer.screenMargin } ?? current.maxX
            let target = NSRect(
                x: rightEdge - size.width,
                y: current.maxY - size.height,
                width: size.width,
                height: size.height
            )
            guard abs(current.origin.x - target.origin.x) > 0.5
                    || abs(current.origin.y - target.origin.y) > 0.5
                    || abs(current.width - target.width) > 0.5
                    || abs(current.height - target.height) > 0.5
            else { return }

            isApplying = true
            defer {
                isApplying = false
            }

            window.disableScreenUpdatesUntilFlush()
            window.setFrame(target, display: false)
            window.displayIfNeeded()
            // The shadow follows the window's alpha, which the size changes.
            window.invalidateShadow()
        }

        deinit {
            tokens.forEach(NotificationCenter.default.removeObserver)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PanelAnchorView {
        let view = PanelAnchorView(frame: .zero)
        view.onAttach = { window in
            window.isMovable = false
            window.isMovableByWindowBackground = false
            context.coordinator.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: PanelAnchorView, context: Context) {
        context.coordinator.size = size
        context.coordinator.isPinned = isPinned
        if let window = nsView.window {
            context.coordinator.attach(to: window)
            context.coordinator.align()
        }
    }
}

// MARK: - Panel scale

/// The five panel sizes, and every dimension that follows from the choice.
///
/// One enum owns all of it deliberately: the row and the preview have to scale
/// together, and spreading the numbers across the views is how they drift apart.
///
/// Declaration order is zoom order: zoom in and zoom out step through
/// `allCases`. Only small, medium and large size the button row. Extra large
/// and full grow the preview alone and keep large's row, so the bar does not
/// keep thickening as the panel widens.
enum PanelScale: String, CaseIterable, Identifiable {
    case small, medium, large, extraLarge, full

    var id: String { rawValue }

    /// Spelled out for tooltips and VoiceOver.
    var helpLabel: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        case .full: "Full Width"
        }
    }

    var smaller: PanelScale? { step(-1) }
    var larger: PanelScale? { step(1) }

    private func step(_ offset: Int) -> PanelScale? {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self) else { return nil }
        let j = i + offset
        return all.indices.contains(j) ? all[j] : nil
    }

    /// Large, extra large and full track the display rather than a hardcoded
    /// number: half, three quarters and all of the screen's width. Each is
    /// clamped to at least the medium width, because on a small display half
    /// the screen can be narrower than medium, which would put the sizes out of
    /// order.
    ///
    /// It is the *panel* that measures the fraction, not the preview inside
    /// it, so the screen margin comes off the top. Sizing the preview to half
    /// the screen instead makes the panel wider than half by exactly that much,
    /// and it laps over a window tiled to the left half.
    ///
    /// The preview is 16:9, so on a 16:9 display a full-width panel is taller
    /// than the screen. Every screen-relative width is therefore also capped at
    /// the widest preview whose panel (preview plus button row) fits the
    /// visible height. On a 16:10 MacBook full is the full width; on a 16:9
    /// monitor it stops a little short of it, and extra large may meet it.
    ///
    /// Every branch returns explicitly. One case here needs more than a single
    /// expression, which makes this a switch statement rather than a switch
    /// expression, and then the one-line cases are no longer implicit returns.
    /// Swift 5.9 (Xcode 15.2, which CI uses) rejects the mix.
    var previewWidth: CGFloat {
        switch self {
        // 400, not the 320 it started at. At 320 the sum of the fixed controls
        // left the camera picker about 6pt wide: present, but neither readable
        // nor clickable, so it went to 380 with the mirror toggle and to 400
        // when the play glyph joined the timer (2026-10-15). The picker is the
        // last thing to get space because it is the only flexible item, so a
        // new button silently comes out of its width.
        case .small: return 400
        case .medium: return 480
        case .large: return screenWidth(fraction: 0.5)
        case .extraLarge: return screenWidth(fraction: 0.75)
        case .full: return screenWidth(fraction: 1)
        }
    }

    private func screenWidth(fraction: CGFloat) -> CGFloat {
        let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 960, height: 600)
        let wanted = (visible.width * fraction - PanelSizer.screenMargin).rounded(.down)
        let rowHeight = verticalPaddingTop + controlHeight + verticalPaddingBottom
        let fitsHeight = ((visible.height - rowHeight) * 16 / 9).rounded(.down)
        return max(480, min(wanted, fitsHeight))
    }

    /// 16:9, so the preview matches the aspect of the cameras feeding it.
    var previewHeight: CGFloat { (previewWidth * 9 / 16).rounded() }

    /// The layout box the symbol sits in. `glyphFont` is the symbol's own
    /// point size and the two track together at every scale (14/11 = 0.79,
    /// 16/13 = 0.81, 17/14 = 0.82), so moving one without the other leaves a
    /// symbol rattling in a box that no longer fits it.
    ///
    /// Large is 17, down from 20. At large the glyph box *is* the control's
    /// content -- the bordered style adds almost nothing on top -- so the glyph
    /// is the lever on the height of the whole bar. See `controlHeight`.
    var glyphSize: CGFloat {
        switch self {
        case .small: 14
        case .medium: 16
        case .large, .extraLarge, .full: 17
        }
    }

    var glyphFont: Font {
        switch self {
        case .small: .system(size: 11, weight: .regular)
        case .medium: .system(size: 13, weight: .regular)
        case .large, .extraLarge, .full: .system(size: 14, weight: .regular)
        }
    }

    /// Text in the button row: the camera name and the MM:SS timer.
    ///
    /// `ControlSize` alone does not carry text size, so every scale sets it.
    ///
    /// Large is 13pt, which is the macOS system default for a `.regular`
    /// control. It used to be 15, and the comment here used to argue for 15 on
    /// the grounds that 13 beside a 20pt glyph reads as too small. That
    /// argument was correct and is not being ignored -- it is being answered on
    /// the other side: the glyph came down to 17 in the same pass, so the
    /// box-to-text ratio is 17/13 = 1.31, near the 20/15 = 1.33 it replaces.
    /// Moving the font alone would have taken it to 1.54 and made the row
    /// worse, which is what the old comment was warning about.
    var controlFont: Font {
        switch self {
        case .small: .system(size: 10)
        case .medium: .system(size: 12)
        case .large, .extraLarge, .full: .system(size: 13)
        }
    }

    /// Only the camera menu reads this now. Every other control in the row is
    /// drawn by `CapsuleToggleStyle`, which takes its height from
    /// `controlHeight` rather than from the platform's control metrics.
    var controlSize: SwiftUI.ControlSize {
        switch self {
        case .small: .mini
        case .medium: .small
        case .large, .extraLarge, .full: .regular
        }
    }

    /// Padding inside the timer's box, between the digits and its border. Its
    /// height comes from `controlHeight` like every other item in the row.
    var timerPaddingH: CGFloat {
        switch self {
        case .small: 5
        case .medium: 6
        case .large, .extraLarge, .full: 8
        }
    }

    /// Diameter of the blinking recording dot on the audio button.
    var recordingDotSize: CGFloat {
        switch self {
        case .small: 5
        case .medium: 6
        case .large, .extraLarge, .full: 7
        }
    }

    var rowSpacing: CGFloat {
        switch self {
        // Six gaps at this scale, so each point here costs the picker six.
        case .small: 8
        case .medium: 14
        case .large, .extraLarge, .full: 18
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: 10
        case .medium: 12
        case .large, .extraLarge, .full: 16
        }
    }

    /// Top and bottom are separate numbers, and at large they differ.
    ///
    /// The two gaps are not the same kind of gap. The top gap sits between the
    /// row and the window's own edge, where there is nothing. The bottom gap
    /// sits between the row and the hard, dark, high-contrast top edge of the
    /// preview image, which visually pulls. Equal numbers therefore read
    /// bottom-heavy, so the bottom gets a point less than the top.
    ///
    /// Large is 7/6, down from 11/11. That takes the whole bar from roughly
    /// 43pt to roughly 32pt, about 1.14x the height of Photo Booth's title bar
    /// rather than 1.52x. Medium and small are unchanged in this pass: the
    /// large numbers are meant to be looked at on hardware before the other two
    /// follow, and small in particular has no width left to give.
    var verticalPaddingTop: CGFloat {
        switch self {
        case .small: 6
        case .medium: 8
        case .large, .extraLarge, .full: 7
        }
    }

    var verticalPaddingBottom: CGFloat {
        switch self {
        case .small: 6
        case .medium: 8
        case .large, .extraLarge, .full: 6
        }
    }

    /// The height every control in the row holds, in every state.
    ///
    /// Stated once here rather than left to each control's own content, and
    /// that is load-bearing twice over. The semantic capsules change silhouette
    /// between off and on, so a constant cap height is the only thing keeping
    /// the row on one horizontal baseline. And the pin used to render 6-7px
    /// taller than its eight siblings despite carrying an identical modifier
    /// chain, because the bordered button style sized its own background from
    /// the label's intrinsic symbol metrics rather than from the glyph frame.
    /// A background drawn against this number cannot do that.
    ///
    /// Large is 22pt, the HIG minimum for a control: nine of these are click
    /// targets and two of them start a recording, so the Photo Booth parity
    /// work stops at the floor rather than going under it. Medium and small
    /// hold the heights they render at today.
    var controlHeight: CGFloat {
        switch self {
        case .small: 17
        case .medium: 20
        case .large, .extraLarge, .full: 22
        }
    }

    /// Horizontal padding inside a control, either side of the glyph box.
    ///
    /// **One number for both states, and it must stay that way.** It used to be
    /// 6 when on and 4 when off, on the argument that the capsule's round ends
    /// need the extra 2pt to clear the glyph. The cost was that every control
    /// grew 4pt the moment it lit: starting a recording pushed the timer, the
    /// video button, the mirror, the camera menu, S/M/L and quit 4pt to the
    /// right, and pressing pin or mirror did the same to everything after them.
    /// A row that moves when you use it is worse than a capsule with tight
    /// ends, and the ends measure fine: at the large scale the cap's inner edge
    /// is 4.0pt in at the glyph box's top corner, which the glyph's own ink
    /// sits inside of.
    ///
    /// If this is ever raised, raise it for both states at once and check
    /// `previewWidth` first -- it comes out of the camera menu, which is the
    /// only flexible item in the row, and 2pt here is 32pt off the menu.
    var controlPaddingH: CGFloat { 4 }

    /// The green well the camera menu's chevron sits in.
    var chevronWellWidth: CGFloat {
        switch self {
        case .small: 11
        case .medium: 13
        case .large, .extraLarge, .full: 14
        }
    }

    var chevronFont: Font {
        switch self {
        case .small: .system(size: 7, weight: .semibold)
        case .medium: .system(size: 8, weight: .semibold)
        case .large, .extraLarge, .full: .system(size: 9, weight: .semibold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: 4
        case .medium: 5
        case .large, .extraLarge, .full: 6
        }
    }

    var pickerMaxWidth: CGFloat {
        switch self {
        case .small: 110
        case .medium: 200
        case .large, .extraLarge, .full: 260
        }
    }
}

// MARK: - Open on launch

/// Opens the panel at launch and on reopen.
///
/// Every launch opens it (Spotlight, Finder, Dock, MacAppLauncher's
/// `--open-panel`) except a login-item launch: popping the panel, and with it
/// the camera, at every login is not wanted. Unverified: whether an
/// `SMAppService` login item carries `keyAELaunchedAsLogInItem` the way a
/// classic login item does. If the panel opens at login, that is why.
///
/// Key is asserted once more after 0.3s, because a launch from Spotlight or
/// another app can leave that app frontmost and the panel would not take
/// keystrokes.
@MainActor
enum PanelLaunchOpener {
    static let argument = "--open-panel"
    private static let log = Logger(subsystem: "com.onair", category: "panel")

    /// Call from `applicationDidFinishLaunching`, while the launch Apple event
    /// is still current.
    static func openAfterLaunch() {
        if launchedAsLoginItem && !CommandLine.arguments.contains(argument) {
            log.notice("login item launch; panel left closed")
            return
        }
        open()
    }

    /// Spotlight, Finder or the Dock on an app that is already running.
    static func openOnReopen() {
        open()
    }

    private static func open() {
        PanelController.shared?.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            MainActor.assumeIsolated { PanelController.shared?.show() }
        }
    }

    private static var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == AEEventID(kAEOpenApplication) else { return false }
        // Explicit conversions: these constants import as different integer
        // types across SDKs, and these inits are no-ops where they already match.
        return event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
            == OSType(keyAELaunchedAsLogInItem)
    }
}

/// Launch and reopen hooks, which SwiftUI's `App` does not expose.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        PanelSizer.applyActivationPolicy(pinned: UserDefaults.standard.bool(forKey: "panelPinned"))
        PanelController.install()
        PanelLaunchOpener.openAfterLaunch()
        GlobalHotKey.register()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PanelLaunchOpener.openOnReopen()
        return false
    }
}

/// ⌃⌥⌘R opens the panel from anywhere, so a panel closed with ⌘W can be
/// brought back without the mouse. It is the app's one global hotkey: every
/// other shortcut lives in the panel's local key monitor and dies with it.
///
/// Carbon's `RegisterEventHotKey`, not `NSEvent.addGlobalMonitorForEvents`:
/// the monitor needs Accessibility or Input Monitoring permission, which the
/// app has never asked for, and the hotkey needs none. It opens, never closes.
///
@MainActor
enum GlobalHotKey {
    private static var hotKey: EventHotKeyRef?
    private static var handler: EventHandlerRef?
    private static let log = Logger(subsystem: "com.onair", category: "panel")

    static func register() {
        guard hotKey == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // A C callback cannot capture, and there is only one hotkey, so the
        // event is not inspected.
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { PanelController.shared?.show() }
            }
            return noErr
        }, 1, &spec, nil, &handler)
        guard installed == noErr else {
            log.error("hotkey handler not installed: \(installed, privacy: .public)")
            return
        }
        let id = EventHotKeyID(signature: OSType(0x4D52_5744), id: 1) // 'MRWD'
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_R), UInt32(cmdKey | optionKey | controlKey),
            id, GetApplicationEventTarget(), 0, &hotKey
        )
        if status != noErr {
            // eventHotKeyExistsErr (-9878) means something else already holds it.
            log.error("⌃⌥⌘R not registered: \(status, privacy: .public)")
        }
    }
}

// MARK: - Panel controller

/// The menu bar item and the panel, both created at launch and kept for the
/// app's lifetime.
///
/// This replaced `MenuBarExtra(.window)` on 2026-10-24. That scene creates its
/// window only on the first click of the menu bar icon, and on macOS 27
/// nothing in the app can produce that click (the scene's status item has no
/// target or action; the click arrives system-side). So the panel could not
/// open at launch, and ⌃⌥⌘R did nothing until the icon had been clicked once.
/// Owning the window removes both problems and every workaround that scene
/// needed (the reverted origin, re-showing after resign key).
///
/// Unpinned, the panel closes when another app becomes active, except
/// Shortcuts and Voice Memos, which a starting or stopping audio recording
/// brings forward (`reclaimFocusFromRecorder` hands key back). Pinned it stays,
/// as `PanelSizer` describes.
@MainActor
final class PanelController: NSObject {
    static private(set) var shared: PanelController?

    static func install() {
        guard shared == nil else { return }
        shared = PanelController()
    }

    let recordingManager: RecordingManager
    let camera: CameraManager
    let playback: PlaybackManager

    private let statusItem: NSStatusItem
    private let panel: PanelWindow
    private var shownAt = Date.distantPast
    private var activationObserver: NSObjectProtocol?

    /// Matches the preview's bottom corners (`CameraPreviewPanel`).
    private static let cornerRadius: CGFloat = 10

    private override init() {
        recordingManager = RecordingManager()
        camera = CameraManager()
        playback = PlaybackManager()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        panel = PanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isReleasedWhenClosed = false
        // Unpinned level. Below modal panels, so an alert is never hidden
        // behind the panel. `PanelSizer` drops it to .normal while pinned.
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = Self.roundedMask(radius: Self.cornerRadius)
        let host = NSHostingView(rootView: PanelView(
            recordingManager: recordingManager,
            camera: camera,
            playback: playback
        ))
        // PanelSizer sizes the window from the measured content; the hosting
        // view resizing it as well would fight that.
        host.sizingOptions = []
        host.autoresizingMask = [.width, .height]
        panel.contentView = background
        host.frame = background.bounds
        background.addSubview(host)

        statusItem.autosaveName = "OnAir"
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.setAccessibilityLabel("OnAir")
            let icon = PassthroughHostingView(rootView: StatusIcon(manager: recordingManager))
            icon.frame = button.bounds
            icon.autoresizingMask = [.width, .height]
            button.addSubview(icon)
        }

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let pid = app?.processIdentifier
            let bundleID = app?.bundleIdentifier
            MainActor.assumeIsolated { self?.otherAppActivated(pid: pid, bundleID: bundleID) }
        }
    }

    private var isPinned: Bool { UserDefaults.standard.bool(forKey: "panelPinned") }

    /// Opens the panel, or raises and gives key to one already open. Never
    /// closes it.
    func show() {
        if !panel.isVisible {
            place()
            shownAt = Date()
            playback.refreshIfMissing()
            playback.reloadLibrary()
            Task { await camera.start() }
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    /// Closes the panel, pinned or not. The camera pauses rather than tearing
    /// down: the session stays configured so the next open skips device
    /// discovery and format negotiation, and `pause()` refuses to stop while a
    /// movie is being written, which is what lets a video recording survive
    /// the panel closing. Playback stops: nothing is lost, and the next open
    /// should show the live camera.
    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        playback.stop()
        camera.pause()
        // Hand focus back to the app the panel was opened over.
        if !isPinned, NSApp.isActive { NSApp.deactivate() }
    }

    @objc private func statusItemClicked() {
        if panel.isVisible, panel.isKeyWindow, NSApp.isActive {
            hide()
        } else {
            show()
        }
    }

    private func otherAppActivated(pid: pid_t?, bundleID: String?) {
        guard let pid, pid != ProcessInfo.processInfo.processIdentifier,
              !isPinned, panel.isVisible,
              // The app that launched or summoned us can take its activation
              // back a moment later; that is not the user leaving.
              Date().timeIntervalSince(shownAt) > 0.5,
              !["com.apple.shortcuts", "com.apple.VoiceMemos"].contains(bundleID ?? "")
        else { return }
        hide()
    }

    /// Top right of the screen holding the menu bar item, at the content's
    /// size, so the first frame painted is already in place. `PanelSizer`
    /// keeps it there as the content changes.
    private func place() {
        let size = panel.contentView?.subviews.first?.fittingSize ?? .zero
        let current = panel.frame.size
        let width = size.width > 0 ? size.width : current.width
        let height = size.height > 0 ? size.height : current.height
        guard let screen = statusItem.button?.window?.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        panel.setFrame(
            NSRect(x: visible.maxX - width, y: visible.maxY - height, width: width, height: height),
            display: false
        )
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// Borderless, so it has to opt in to key status, or no keystroke reaches the
/// panel's key monitor.
final class PanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Esc that the key monitor passed through (nothing recording). NSPanel
    /// would close itself here, skipping the camera pause; close properly.
    override func cancelOperation(_ sender: Any?) {
        PanelController.shared?.hide()
    }
}

/// The menu bar icon, drawn by SwiftUI inside the status item's button.
private struct StatusIcon: View {
    let manager: RecordingManager

    var body: some View {
        MenuBarIcon(isRecording: manager.isRecording)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Lets clicks through to the status item's button underneath.
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
