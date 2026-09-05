import AppKit
import SwiftUI

/// Temporary diagnostics for the panel-positioning problem. Writes to
/// /tmp/macrecordwidget-panel.log so the actual window identity and frames can
/// be inspected instead of guessed at.
enum PanelLog {
    static let path = "/tmp/macrecordwidget-panel.log"

    static func write(_ message: String) {
        let line = "[\(Date())] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    static func dumpWindows(_ tag: String) {
        let windows = NSApp.windows.map { w in
            "\(type(of: w)) frame=\(w.frame) visible=\(w.isVisible) level=\(w.level.rawValue)"
        }
        write("\(tag) NSApp.windows(\(windows.count)): \(windows.joined(separator: " | "))")
    }
}

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
            PanelLog.write("viewDidMoveToWindow: \(type(of: window)) frame=\(window.frame) screen=\(String(describing: window.screen?.visibleFrame))")
            PanelLog.dumpWindows("attach")
            onAttach?(window)
        } else {
            PanelLog.write("viewDidMoveToWindow: window is nil")
        }
    }
}

/// Pins the `MenuBarExtra(.window)` panel to the right of the screen and keeps
/// it sized to its content.
///
/// AppKit fights this in three ways: it grows the panel to fit content but
/// never shrinks it back, it re-anchors the panel under the status item on each
/// open, and it does that positioning after SwiftUI's view update. So rather
/// than trying to win a race, this observes the window's own move and resize
/// notifications and corrects the frame whenever AppKit changes it.
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
            PanelLog.write("align current=\(current) target=\(target) rightEdge=\(rightEdge) screenVisible=\(String(describing: screen?.visibleFrame))")
            guard abs(current.origin.x - target.origin.x) > 0.5
                    || abs(current.origin.y - target.origin.y) > 0.5
                    || abs(current.width - target.width) > 0.5
                    || abs(current.height - target.height) > 0.5
            else { return }

            isApplying = true
            defer {
                isApplying = false
                PanelLog.write("applied -> frame=\(window.frame)")
            }

            // MenuBarExtraWindow reverts the origin inside setFrame to keep
            // itself anchored to the status item, so the size lands but the
            // move is discarded. Try to reassert the origin outside that call.
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.22
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.animator().setFrame(target, display: true)
                }
            } else {
                window.setFrame(target, display: true)
            }

            let origin = target.origin
            DispatchQueue.main.async { [weak window] in
                guard let window else { return }
                window.setFrameOrigin(origin)
                PanelLog.write("deferred setFrameOrigin(\(origin)) -> \(window.frame)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak window] in
                    guard let window else { return }
                    PanelLog.write("settled -> \(window.frame)")
                }
            }
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
