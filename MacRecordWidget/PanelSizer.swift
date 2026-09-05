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
    let animated: Bool

    /// Gap between the panel's trailing edge and the right of the screen.
    fileprivate static let screenMargin: CGFloat = 8

    final class Coordinator {
        var size: CGSize = .zero
        var animated = false
        private var tokens: [NSObjectProtocol] = []
        private weak var window: NSWindow?
        private var isApplying = false

        func attach(to window: NSWindow) {
            guard self.window !== window else {
                align(animated: false)
                return
            }
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens.removeAll()
            self.window = window

            let center = NotificationCenter.default
            for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
                tokens.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.align(animated: false) }
                })
            }
            align(animated: false)
        }

        func align(animated: Bool) {
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
        context.coordinator.animated = animated
        if let window = nsView.window {
            context.coordinator.attach(to: window)
            context.coordinator.align(animated: animated)
        }
    }
}
