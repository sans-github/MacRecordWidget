import AppKit
import Foundation
import Observation

/// Which kind of recording is in progress. The two are mutually exclusive.
enum RecordingMedium {
    /// Voice Memos, driven by the "Start"/"Stop" Shortcuts.
    case audio
    /// An in-app `AVCaptureMovieFileOutput` writing into Photo Booth's library.
    case video
}

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
    /// True while *either* medium is capturing. `medium` says which.
    var isRecording = false
    var isInFlight = false

    /// Which medium is arming or recording, and `nil` when idle.
    ///
    /// Audio and video are mutually exclusive, so this is the whole of the
    /// mode state: one clock, one meaning, and each button disables the other
    /// while it is set. Nothing here supports two simultaneous recordings and
    /// that is deliberate -- a shared timer cannot honestly describe two
    /// recordings that started at different moments.
    private(set) var medium: RecordingMedium?

    var isRecordingAudio: Bool { isRecording && medium == .audio }
    var isRecordingVideo: Bool { isRecording && medium == .video }

    /// True from the moment either button is pressed until its recording ends.
    /// This, not `isRecording`, is what disables the other button: the arming
    /// window is already committed to a medium.
    var isBusy: Bool { medium != nil }

    /// Called when a recording fails after the user has stopped looking at the
    /// button, i.e. from inside the arming task, where there is no call stack
    /// left to throw back into.
    @ObservationIgnored var onError: ((Error) -> Void)?

    /// True between firing the Start shortcut and the point where Voice Memos
    /// is actually capturing. The UI shows a distinct "starting" state so the
    /// user knows not to speak yet.
    ///
    /// This exists because there is no signal for "capture has begun".
    /// Measured: the `.m4a` does not appear until *after* Stop, the process is
    /// up 1.3s before audio flows, and the filename records when the shortcut
    /// fired rather than when recording started. So the delay is a constant.
    private(set) var isArming = false

    /// How long to wait before declaring the recording live.
    ///
    /// Measured 2026-09-06 by firing Start, waiting a known interval, firing
    /// Stop and comparing against the audio duration in the resulting file:
    /// 1.54s lost with Voice Memos quit, 0.88-0.93s with it already running
    /// (n=3, spread 0.05s). Set to 3s: comfortably above the measured 1.54s,
    /// because losing the first words costs more than waiting an extra second,
    /// and the measurement was taken on an idle machine.
    /// Tune here; nothing else depends on the value.
    static let armingDelay: Duration = .milliseconds(3000)

    private var armingTask: Task<Void, Never>?

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
        guard !isInFlight, medium == nil else { return }
        isInFlight = true
        medium = .audio
        // Claim the medium up front so the video button is disabled for the
        // whole attempt, including the ~1.5s Voice Memos quit below, but
        // release it again on any failure path or the app is stuck in a mode
        // that never started.
        var committed = false
        defer {
            isInFlight = false
            if !committed { medium = nil }
        }

        // Voice Memos must not be running when Start fires, or macOS raises
        // VMAudioServiceErrorDomain error 5. See CLAUDE.md "Gotchas".
        //
        // `stopRecording()` now quits it, so on the common path it is already
        // gone and this costs nothing. This is the fallback for the first
        // recording after launch, or if the user opened Voice Memos by hand.
        // Keeping the quit here is deliberate: warm starts were measured
        // working, but four successes are not enough to delete a documented
        // failure mode whose trigger conditions are unknown.
        if let voiceMemos = Self.runningVoiceMemos() {
            voiceMemos.terminate()
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
        //
        // Recording is not live yet: Shortcuts still has to run and Voice Memos
        // still has to arm the mic. Hold an explicit arming state for that
        // window so the timer does not over-report and the user is not invited
        // to start talking into a mic that is not listening.
        isArming = true
        armingTask?.cancel()
        armingTask = Task { [weak self] in
            try? await Task.sleep(for: Self.armingDelay)
            guard !Task.isCancelled, let self else { return }
            self.isArming = false
            // The clock resets here, not on stop, so the previous recording's
            // duration stays readable until a new one actually begins.
            self.lastElapsed = 0
            self.startedAt = Date()
            self.isRecording = true
        }
        committed = true
    }

    func stopRecording() async throws {
        guard !isInFlight else { return }
        isInFlight = true
        defer { isInFlight = false }

        // Stopping during the arming window must not leave a pending task that
        // flips the UI to "recording" seconds after the user stopped.
        armingTask?.cancel()
        armingTask = nil
        isArming = false

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
        medium = nil

        // Quit Voice Memos here rather than before the next Start. The app has
        // to guarantee it is not running when Start fires, and paying that cost
        // now moves ~1.5s of dead time out of the moment the user is waiting to
        // speak. The delay gives Voice Memos time to finish writing the file.
        Task {
            try? await Task.sleep(for: .seconds(2))
            Self.runningVoiceMemos()?.terminate()
        }
    }

    // MARK: - Video

    /// Starts a video recording after the same arming delay the audio path
    /// uses.
    ///
    /// The delay is a real wait, not a cosmetic one: capture begins *after* it,
    /// so the saved `.mov` is exactly as long as the timer said. Showing an
    /// arming state while the file was already growing would make every
    /// recording ~3s longer than its own readout.
    ///
    /// Unlike audio, this has a genuine "capture has begun" signal from
    /// AVFoundation. The delay is kept anyway so the two buttons feel the same;
    /// see `armingDelay`.
    func startVideoRecording(camera: CameraManager) async throws {
        guard !isInFlight, medium == nil else { return }
        isInFlight = true
        medium = .video
        var committed = false
        defer {
            isInFlight = false
            if !committed { medium = nil }
        }

        guard camera.canRecordVideo else {
            throw VideoRecordingError.cameraNotReady
        }

        isArming = true
        armingTask?.cancel()
        armingTask = Task { [weak self] in
            try? await Task.sleep(for: Self.armingDelay)
            guard !Task.isCancelled, let self else { return }
            do {
                try await camera.startRecording()
            } catch {
                // Nothing is left to throw into: the caller returned three
                // seconds ago. Reset and report through the app's alert path.
                self.isArming = false
                self.medium = nil
                self.onError?(error)
                return
            }
            // Stop may have landed while the mic was being attached above.
            guard !Task.isCancelled else {
                await camera.stopRecording()
                self.isArming = false
                self.medium = nil
                return
            }
            self.isArming = false
            // The clock resets here, not on stop, so the previous recording's
            // duration stays readable until a new one actually begins.
            self.lastElapsed = 0
            self.startedAt = Date()
            self.isRecording = true
        }
        committed = true
    }

    /// Stops the video recording and waits for the file to be closed and
    /// indexed. Safe to call during the arming window.
    func stopVideoRecording(camera: CameraManager) async {
        guard !isInFlight else { return }
        isInFlight = true
        defer { isInFlight = false }

        // Stopping during arming must not leave a pending task that starts a
        // recording seconds after the user stopped.
        armingTask?.cancel()
        armingTask = nil
        isArming = false

        await camera.stopRecording()

        if let startedAt {
            lastElapsed = max(0, Date().timeIntervalSince(startedAt))
        }
        startedAt = nil
        isRecording = false
        medium = nil
    }

    private static func runningVoiceMemos() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.VoiceMemos" })
    }
}
