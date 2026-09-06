import AppKit
import Foundation
import Observation

enum RecordingError: Error, LocalizedError {
    case shortcutLaunchFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .shortcutLaunchFailed(let reason):
            return "Could not launch the recording shortcut. \(reason)"
        }
    }
}

// `@MainActor` is required, not cosmetic: `startRecording()` and `stopRecording()`
// mutate observable state after `await` points. Without actor isolation those
// mutations land off the main thread while SwiftUI observes them on it.
@MainActor
@Observable
final class RecordingManager {
    var isRecording = false
    /// Controls the in-popover camera preview only. It does NOT affect what is
    /// recorded: recording is audio, via the "Start" Shortcut into Voice Memos.
    /// Photo Booth is no longer launched.
    var videoEnabled = false
    var isInFlight = false

    /// When the current recording started, or nil when not recording.
    ///
    /// The elapsed time is derived from this rather than accumulated by a
    /// ticking counter, so it stays correct while the panel is closed and
    /// cannot drift. Nothing has to run in the background to keep it accurate.
    private(set) var startedAt: Date?

    /// Elapsed time of the last finished recording. Held on screen after stop
    /// until the next recording begins, and 0 before the first one, which is
    /// what puts 00:00 on screen at launch.
    private(set) var lastElapsed: TimeInterval = 0

    /// Seconds to display: live while recording, otherwise the retained value.
    func elapsed(asOf now: Date = Date()) -> TimeInterval {
        guard let startedAt else { return lastElapsed }
        return max(0, now.timeIntervalSince(startedAt))
    }

    /// MM:SS. Minutes are not capped at 59, so a long recording reads 74:05
    /// rather than wrapping back to 14:05.
    static func formatElapsed(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded(.down))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func startRecording() async throws {
        guard !isInFlight else { return }
        isInFlight = true
        defer { isInFlight = false }

        // Quit Voice Memos before firing the Start shortcut. If Voice Memos is
        // open, macOS raises VMAudioServiceErrorDomain error 5. The 1.5s wait
        // gives it time to fully exit. See CLAUDE.md "Gotchas".
        let voiceMemos = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.VoiceMemos" })
        voiceMemos?.terminate()
        if voiceMemos != nil {
            try await Task.sleep(for: .seconds(1.5))
        }

        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let name = "Recording-\(timestamp)"

        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "shortcuts://run-shortcut?name=Start&input=text&text=\(encoded)")
        else {
            throw RecordingError.shortcutLaunchFailed(reason: "Could not construct shortcut URL")
        }

        let opened = NSWorkspace.shared.open(url)
        guard opened else {
            throw RecordingError.shortcutLaunchFailed(reason: "NSWorkspace.open returned false")
        }

        // State is set only after the URL opens successfully (AC-SW-7).
        // The clock resets here, not on stop, so the previous recording's
        // duration stays readable until a new one actually begins.
        lastElapsed = 0
        startedAt = Date()
        isRecording = true
    }

    func stopRecording() async throws {
        guard !isInFlight else { return }
        isInFlight = true
        defer { isInFlight = false }

        guard let url = URL(string: "shortcuts://run-shortcut?name=Stop") else {
            throw RecordingError.shortcutLaunchFailed(reason: "Could not construct Stop shortcut URL")
        }

        let opened = NSWorkspace.shared.open(url)
        guard opened else {
            throw RecordingError.shortcutLaunchFailed(reason: "NSWorkspace.open returned false for Stop")
        }

        if let startedAt {
            lastElapsed = max(0, Date().timeIntervalSince(startedAt))
        }
        startedAt = nil
        isRecording = false
    }
}
