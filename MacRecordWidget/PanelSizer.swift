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
        case .small: return 320
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

    var glyphSize: CGFloat {
        switch self {
        case .small: 14
        case .medium: 16
        case .large: 20
        }
    }

    var glyphFont: Font {
        switch self {
        case .small: .system(size: 11, weight: .regular)
        case .medium: .system(size: 13, weight: .regular)
        case .large: .system(size: 16, weight: .regular)
        }
    }

    /// Text in the button row: the camera name and the MM:SS timer.
    ///
    /// `ControlSize` alone does not carry this. `.regular` still draws 13pt
    /// text, which next to 20pt glyphs in a taller row reads as too small, so
    /// large sets the font explicitly.
    var controlFont: Font {
        switch self {
        case .small: .system(size: 10)
        case .medium: .system(size: 12)
        case .large: .system(size: 15)
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
        case .large: .system(size: 15)
        }
    }

    var controlSize: ControlSize {
        switch self {
        case .small: .mini
        case .medium: .small
        case .large: .regular
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
        case .small: 10
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

    var verticalPadding: CGFloat {
        switch self {
        case .small: 6
        case .medium: 8
        case .large: 11
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
        case .small: 150
        case .medium: 200
        case .large: 260
        }
    }
}
