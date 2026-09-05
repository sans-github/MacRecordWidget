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
/// AppKit grows that panel to fit its content but does not shrink it again when
/// the content collapses, which leaves a full-size empty panel behind after the
/// preview closes. Setting the frame explicitly fixes that, and lets us pin the
/// top-trailing corner so the panel grows leftward and downward while the
/// button row stays visually still.
struct PanelSizer: NSViewRepresentable {
    let size: CGSize
    let animated: Bool

    /// Gap between the panel's trailing edge and the right of the screen.
    private static let screenMargin: CGFloat = 8

    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard size.width > 0, size.height > 0 else { return }
        // Deferred: the window is not attached during the first layout pass.
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            // Let the user drag the panel while it is open. AppKit still
            // re-anchors it under the status item on each open, and it still
            // dismisses on an outside click; this only frees it while visible.
            if !window.isMovableByWindowBackground {
                window.isMovable = true
                window.isMovableByWindowBackground = true
            }
            let current = window.frame
            let sizeChanged = abs(current.width - size.width) > 0.5 || abs(current.height - size.height) > 0.5
            guard sizeChanged else { return }

            // Align the trailing edge to the right of the screen, so the panel
            // grows leftward from a fixed edge instead of from wherever AppKit
            // happened to anchor it under the status item. Falls back to the
            // current maxX if no screen can be resolved.
            let screen = window.screen ?? NSScreen.main
            let rightEdge = screen.map { $0.visibleFrame.maxX - Self.screenMargin } ?? current.maxX
            let target = NSRect(
                x: rightEdge - size.width,
                y: current.maxY - size.height,
                width: size.width,
                height: size.height
            )

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
    }
}
