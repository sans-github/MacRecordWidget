import AppKit
import Foundation
import Observation

enum RecordingError: Error, LocalizedError {
    case shortcutLaunchFailed(reason: String)
    case accessibilityDenied

    var errorDescription: String? {
        switch self {
        case .shortcutLaunchFailed(let reason):
            return "Could not launch the recording shortcut. \(reason)"
        case .accessibilityDenied:
            return "Accessibility permission was denied."
        }
    }
}

@Observable
final class RecordingManager {
    var isRecording = false
    var videoEnabled = false
    var isInFlight = false

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

        // State is set only after the URL opens successfully (AC-SW-7)
        isRecording = true

        if videoEnabled {
            try await launchPhotoBooth()
        }
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

        isRecording = false

        if videoEnabled {
            NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == "com.apple.PhotoBooth" })?
                .terminate()
        }
    }

    private func launchPhotoBooth() async throws {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Photo Booth.app"))
        // Wait for Photo Booth to finish launching before sending AX event
        try await Task.sleep(for: .seconds(2.0))

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e",
            "tell application \"System Events\" to tell process \"Photo Booth\" " +
            "to set value of attribute \"AXFullScreen\" of window 1 to true"
        ]
        let stderrPipe = Pipe()
        task.standardError = stderrPipe
        try task.run()
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            // Only surface an error if Accessibility was actually denied. Other failures
            // (e.g. Photo Booth window not yet ready) are timing issues and not user-actionable.
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
            if stderrText.localizedCaseInsensitiveContains("not allowed assistive") ||
               stderrText.localizedCaseInsensitiveContains("accessibility") {
                isRecording = false
                throw RecordingError.accessibilityDenied
            }
            // Non-Accessibility failure: Photo Booth opened but full-screen failed. Not fatal.
        }
    }
}
