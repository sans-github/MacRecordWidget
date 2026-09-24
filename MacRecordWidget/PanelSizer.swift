import AppKit
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

    final class Coordinator {
        var size: CGSize = .zero
        var isPinned = false
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

            let center = NotificationCenter.default
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
                tokens.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.align() }
                })
            }
            tokens.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.keepVisibleIfPinned() }
            })
            align()
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
            guard isPinned else { return }
            orderFront()
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.orderFront() }
            }
        }

        private func orderFront() {
            guard isPinned, let window, !window.isVisible else { return }
            window.orderFrontRegardless()
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

/// The three panel sizes, and every dimension that follows from the choice.
///
/// One enum owns all of it deliberately: the row and the preview have to scale
/// together, and spreading the numbers across the views is how they drift apart.
enum PanelScale: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var label: String {
        switch self {
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        }
    }

    /// Spelled out for tooltips and VoiceOver, where a bare letter says nothing.
    var helpLabel: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    /// Large tracks the display rather than a hardcoded number, so it is half
    /// the screen on any Mac. Clamped to at least the medium width, because on
    /// a small display half the screen can be narrower than medium, which would
    /// put the sizes out of order.
    ///
    /// It is the *panel* that measures half the screen, not the preview inside
    /// it, so the padding and the screen margin come off the top. Sizing the
    /// preview to half the screen instead makes the panel wider than half by
    /// exactly that much, and it laps over a window tiled to the left half.
    /// Every branch returns explicitly. One case here needs more than a single
    /// expression, which makes this a switch statement rather than a switch
    /// expression, and then the one-line cases are no longer implicit returns.
    /// Swift 5.9 (Xcode 15.2, which CI uses) rejects the mix.
    var previewWidth: CGFloat {
        switch self {
        // 380, not the 320 it used to be. The row has seven control groups
        // now, and at 320 the sum of the fixed ones left the camera picker
        // about 6pt wide: present, but neither readable nor clickable. The
        // picker is the last thing to get space because it is the only
        // flexible item, so a new button silently comes out of its width.
        case .small: return 380
        case .medium: return 480
        case .large:
            // The preview runs the full width of the panel, so this is the
            // panel width too and large can be half the screen exactly.
            let screenWidth = NSScreen.main?.visibleFrame.width ?? 960
            return max(480, (screenWidth / 2 - PanelSizer.screenMargin).rounded(.down))
        }
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
        case .large: 17
        }
    }

    var glyphFont: Font {
        switch self {
        case .small: .system(size: 11, weight: .regular)
        case .medium: .system(size: 13, weight: .regular)
        case .large: .system(size: 14, weight: .regular)
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
        case .large: .system(size: 13)
        }
    }

    /// The S/M/L letters. A letter fills its box more solidly than a glyph
    /// does, so at the small scale it needs to be a point under `controlFont`
    /// to carry the same weight as the icons beside it. At medium and large the
    /// two agree.
    var scaleLabelFont: Font {
        switch self {
        case .small: .system(size: 9)
        case .medium: .system(size: 12)
        case .large: .system(size: 13)
        }
    }

    /// Only the camera menu reads this now. Every other control in the row is
    /// drawn by `CapsuleToggleStyle`, which takes its height from
    /// `controlHeight` rather than from the platform's control metrics.
    var controlSize: ControlSize {
        switch self {
        case .small: .mini
        case .medium: .small
        case .large: .regular
        }
    }

    /// Padding inside the timer's box, between the digits and its border. Its
    /// height comes from `controlHeight` like every other item in the row.
    var timerPaddingH: CGFloat {
        switch self {
        case .small: 5
        case .medium: 6
        case .large: 8
        }
    }

    /// Diameter of the blinking recording dot on the audio button.
    var recordingDotSize: CGFloat {
        switch self {
        case .small: 5
        case .medium: 6
        case .large: 7
        }
    }

    var rowSpacing: CGFloat {
        switch self {
        // Six gaps at this scale, so each point here costs the picker six.
        case .small: 8
        case .medium: 14
        case .large: 18
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: 10
        case .medium: 12
        case .large: 16
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
        case .large: 7
        }
    }

    var verticalPaddingBottom: CGFloat {
        switch self {
        case .small: 6
        case .medium: 8
        case .large: 6
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
        case .large: 22
        }
    }

    /// Horizontal padding inside a control, either side of the glyph box.
    ///
    /// An on control is 2pt wider than an off one, because the capsule's round
    /// ends need that much to clear the glyph. That growth comes out of the
    /// camera menu, which is the only flexible item in the row -- check
    /// `previewWidth` before adding anything else here.
    func controlPaddingH(isOn: Bool) -> CGFloat {
        isOn ? 6 : 4
    }

    /// The green well the camera menu's chevron sits in.
    var chevronWellWidth: CGFloat {
        switch self {
        case .small: 11
        case .medium: 13
        case .large: 14
        }
    }

    var chevronFont: Font {
        switch self {
        case .small: .system(size: 7, weight: .semibold)
        case .medium: .system(size: 8, weight: .semibold)
        case .large: .system(size: 9, weight: .semibold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: 4
        case .medium: 5
        case .large: 6
        }
    }

    var pickerMaxWidth: CGFloat {
        switch self {
        case .small: 110
        case .medium: 200
        case .large: 260
        }
    }
}
