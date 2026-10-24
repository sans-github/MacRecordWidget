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

/// Pins the `MenuBarExtra(.window)` panel to the right of the screen and keeps
/// it sized to its content.
///
/// Two AppKit behaviours have to be worked around.
///
/// First, the panel grows to fit its content but never shrinks back, which
/// strands a full-size empty window when the preview closes.
///
/// Second, and less obvious: `MenuBarExtraWindow` keeps itself anchored to the
/// status item by reverting the origin *inside* `setFrame`. The size is
/// honoured and the move is silently discarded, so reading the frame back
/// immediately shows the old x. Measured on a real panel: asking for x=1072
/// landed at x=848, and asking for x=768 landed at x=376.
///
/// The revert is scoped to that call, so `setFrameOrigin` immediately after it
/// sticks. Both are applied with screen updates suppressed and flushed once, so
/// the anchored intermediate position is never painted; correcting it on a
/// later runloop pass instead makes the panel visibly flick from centre to
/// right.
///
/// Do not animate the resize. `animator().setFrame` animates the reverted
/// origin too, sliding the panel across the screen before the correction lands.
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

    /// True for the moment ⌘W is closing the panel, so the pin's resign-key
    /// handler does not put it straight back.
    fileprivate static var isClosingOnRequest = false

    /// Closes the panel as ⌘W asks, pinned or not. The camera pauses through
    /// the content's `onDisappear`, as on any other close. Unverified on
    /// hardware: whether `MenuBarExtra` notices a `close()` it did not start,
    /// so that the next icon click opens rather than needing two clicks.
    static func closePanel() {
        guard let window = panelWindow, window.isVisible else { return }
        isClosingOnRequest = true
        window.close()
        // Two passes, matching keepVisibleIfPinned's own deferred re-show.
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { isClosingOnRequest = false }
            }
        }
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
        /// The level `MenuBarExtra` gave the panel, restored on unpin. Pinned,
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
            tokens.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.keepVisibleIfPinned() }
            })
            // Re-applied on every key change in case MenuBarExtra resets the
            // level when it shows the panel (unverified whether it does).
            tokens.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.applyPinnedBehaviour()
                    self?.raiseIfPinned()
                }
            })
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

        /// A menu bar icon click on macOS 27 arrives as a status-item scene
        /// action, not a mouse event the app can see. For a panel that is
        /// already open, `MenuBarExtra` only makes it key: the window stays
        /// behind the app in front and that app stays frontmost (measured
        /// 2026-10-24). So becoming key is the signal to raise and activate.
        private func raiseIfPinned() {
            guard isPinned, let window else { return }
            window.orderFrontRegardless()
            if NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        /// ⌘Tab (or the Dock icon) back to the app brings the panel forward.
        /// Only a panel still on screen: one closed with ⌘W stays closed.
        private func bringForwardIfPinned() {
            guard isPinned, !PanelSizer.isClosingOnRequest, let window, window.isVisible else { return }
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

            // Any frame change makes AppKit re-anchor the panel to the status
            // item, reverting the origin inside setFrame. Correcting it on a
            // later runloop pass means the anchored position gets painted
            // first, which is the flicker from centre to right. So suppress
            // drawing, apply size and corrected origin together, then flush.
            //
            // The resize is deliberately not animated: animating setFrame
            // animates the reverted origin too, sliding the panel across the
            // screen before the correction lands.
            window.disableScreenUpdatesUntilFlush()
            window.setFrame(target, display: false)
            window.setFrameOrigin(target.origin)
            window.displayIfNeeded()
        }

        /// Re-shows the panel after it resigns key.
        ///
        /// `MenuBarExtra(.window)` closes its panel by ordering it out when the
        /// window stops being key; there is no public switch for that. The
        /// order of our observer against AppKit's own handler is not
        /// guaranteed, so the re-show runs twice: once synchronously (in case
        /// the order-out already happened) and once on the next runloop pass
        /// (in case it has not).
        func keepVisibleIfPinned() {
            guard isPinned, !PanelSizer.isClosingOnRequest else { return }
            orderFront()
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.orderFront() }
            }
        }

        private func orderFront() {
            guard isPinned, !PanelSizer.isClosingOnRequest, let window, !window.isVisible else { return }
            // Re-shown behind the app that took focus, not over it.
            if NSApp.isActive { window.orderFrontRegardless() } else { window.orderBack(nil) }
            align()
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
            // The app is an accessory (LSUIElement), so it deactivates as soon
            // as another app is clicked. Left at the default this would hide
            // the panel before the pin observer ever runs.
            window.hidesOnDeactivate = false
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

/// Opens the panel at launch and on reopen, as if the menu bar icon were clicked.
///
/// Every launch opens it (Spotlight, Finder, Dock, MacAppLauncher's
/// `--open-panel`) except a login-item launch: popping the panel, and with it
/// the camera, at every login is not wanted. Unverified: whether an
/// `SMAppService` login item carries `keyAELaunchedAsLogInItem` the way a
/// classic login item does. If the panel opens at login, that is why.
///
/// SwiftUI has no public API to open a `MenuBarExtra`, and clicking the
/// status item from code does nothing on macOS 27 (its button has no target or
/// action, measured 2026-10-23). So this orders the `MenuBarExtraWindow` in
/// directly, the same move as the ⌃⌥⌘R hotkey (`GlobalHotKey.show`). The
/// window may not exist the instant launching finishes, so it is looked for
/// every 0.1s for up to 3s. Key is then asserted once more, because a launch
/// from Spotlight or another app can leave that app frontmost and the panel
/// would not take keystrokes.
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
        attempt(remaining: 30)
    }

    /// Spotlight, Finder or the Dock on an app that is already running.
    static func openOnReopen() {
        attempt(remaining: 30)
    }

    private static var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == AEEventID(kAEOpenApplication) else { return false }
        // Explicit conversions: these constants import as different integer
        // types across SDKs, and these inits are no-ops where they already match.
        return event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
            == OSType(keyAELaunchedAsLogInItem)
    }

    private static func attempt(remaining: Int) {
        if GlobalHotKey.show() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                MainActor.assumeIsolated { makePanelKey() }
            }
        } else if remaining > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                MainActor.assumeIsolated { attempt(remaining: remaining - 1) }
            }
        } else {
            log.error("no panel window after 3s; panel not opened")
        }
    }

    private static func makePanelKey() {
        guard let window = PanelSizer.panelWindow, window.isVisible, !window.isKeyWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

/// Launch and reopen hooks, which SwiftUI's `App` does not expose.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        PanelSizer.applyActivationPolicy(pinned: UserDefaults.standard.bool(forKey: "panelPinned"))
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
/// It shows the panel's own window rather than clicking the status item:
/// measured 2026-10-23, clicking it from code leaves the
/// `MenuBarExtraWindow` hidden on macOS 27, because the status item's button
/// has no target or action to fire. The window outlives a close, so ordering
/// it back in is the same move the pin's re-show makes.
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
                MainActor.assumeIsolated { GlobalHotKey.show() }
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

    /// Orders the panel in and gives it key. False when the window does not
    /// exist yet, which only happens in the first moments after launch.
    @discardableResult
    static func show() -> Bool {
        let window = PanelSizer.panelWindow ?? NSApp.windows.first {
            String(describing: type(of: $0)).contains("MenuBarExtraWindow")
        }
        guard let window else {
            log.debug("no panel window yet")
            return false
        }
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKey()
        log.notice("panel shown: visible=\(window.isVisible, privacy: .public) key=\(window.isKeyWindow, privacy: .public)")
        return true
    }
}
