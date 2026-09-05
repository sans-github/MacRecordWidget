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

/// Drives the `MenuBarExtra(.window)` panel's own `NSWindow` frame.
///
/// Two AppKit behaviours make this necessary. The panel grows to fit its
/// content but never shrinks back, which strands a full-size empty window when
/// the preview closes. And AppKit re-anchors the panel under the status item
/// every time it opens, which overrides any position set earlier.
///
/// So the frame is applied both when the content size changes and again when
/// the window becomes key, which is the point AppKit has finished positioning
/// it. The trailing edge is pinned to the right of the screen.
struct PanelSizer: NSViewRepresentable {
    let size: CGSize
    let animated: Bool

    /// Gap between the panel's trailing edge and the right of the screen.
    private static let screenMargin: CGFloat = 8

    final class Coordinator {
        var size: CGSize = .zero
        var animated = false
        private var observer: NSObjectProtocol?
        private weak var observed: NSWindow?

        /// Re-applies the frame once AppKit has placed the panel for this open.
        func observe(_ window: NSWindow) {
            guard observed !== window else { return }
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observed = window
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                // Never animate this one: it is a placement correction at open,
                // not a resize the user initiated.
                MainActor.assumeIsolated { self.apply(to: window, animated: false) }
            }
        }

        func apply(to window: NSWindow, animated: Bool) {
            guard size.width > 0, size.height > 0 else { return }
            let current = window.frame
            let screen = window.screen ?? NSScreen.main
            let rightEdge = screen.map { $0.visibleFrame.maxX - PanelSizer.screenMargin } ?? current.maxX
            let target = NSRect(
                x: rightEdge - size.width,
                y: current.maxY - size.height,
                width: size.width,
                height: size.height
            )
            // Reposition when the position is stale too, not only the size.
            guard abs(current.origin.x - target.origin.x) > 0.5
                    || abs(current.origin.y - target.origin.y) > 0.5
                    || abs(current.width - target.width) > 0.5
                    || abs(current.height - target.height) > 0.5
            else { return }

            guard animated else {
                window.setFrame(target, display: true)
                return
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(target, display: true)
            }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.size = size
        context.coordinator.animated = animated
        // Deferred: the window is not attached during the first layout pass.
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            // Dragging stays off: the panel is anchored to the screen edge, and
            // AppKit would re-anchor it on the next open anyway.
            window.isMovable = false
            window.isMovableByWindowBackground = false
            context.coordinator.observe(window)
            context.coordinator.apply(to: window, animated: animated)
        }
    }
}
