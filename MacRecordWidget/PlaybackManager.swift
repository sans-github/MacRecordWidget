import AppKit
import AVFoundation
import Foundation
import Observation
import os

let playbackLog = Logger(subsystem: "com.macrecordwidget", category: "playback")

/// The recording the play control replays. Persisted in `UserDefaults` so the
/// control survives a relaunch.
struct LastRecording: Codable, Equatable {
    let medium: RecordingMedium
    /// The movie for video. For audio, nil until the Voice Memos file has been
    /// found, then remembered so later presses skip the search.
    var url: URL?
    /// Seconds. The timer's reading at stop, replaced by the file's own
    /// duration once the file has been opened.
    var duration: TimeInterval
    /// The audio lookup only accepts files created after this.
    let notBefore: Date
}

/// Plays the last recording: audio in place (the row's timer box shows the
/// position), video over the camera preview surface.
///
/// One `AVPlayer` and one `AVPlayerLayer`, both created at init and kept for
/// the app's lifetime. The player layer has nothing to do with the capture
/// session's lock, so it is not under the preview layer's deadlock rule; it is
/// kept anyway so the overlay view can mount and unmount without rebuilding it.
///
/// Playback never touches `CameraManager`: the capture session keeps running
/// underneath a video, so "Live Camera" is instant.
@MainActor
@Observable
final class PlaybackManager {
    enum Phase: Equatable {
        case idle
        /// Looking for the file or loading the asset. For audio this covers
        /// the window after Stop in which Voice Memos has not written the
        /// `.m4a` yet.
        case opening(RecordingMedium)
        case playing(RecordingMedium)
        /// The `.mov` is gone (deleted in Photo Booth). Shown on the surface.
        case videoMissing
    }

    private(set) var phase: Phase = .idle
    private(set) var lastRecording: LastRecording?
    /// Video only. Audio is play/stop.
    private(set) var isPaused = false

    /// The audio file could not be found or opened. The app shows an alert;
    /// audio has no surface of its own to draw a message on.
    @ObservationIgnored var onAudioUnavailable: (() -> Void)?

    let player = AVPlayer()
    let playerLayer: AVPlayerLayer

    @ObservationIgnored private var openTask: Task<Void, Never>?
    @ObservationIgnored private var endTask: Task<Void, Never>?
    @ObservationIgnored private var resolveTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    private let defaults: UserDefaults

    private static let defaultsKey = "lastRecording"

    /// How long a press waits for Voice Memos to write the file (per mocks).
    static let pressTimeout: Duration = .seconds(5)
    /// How long the background lookup after Stop keeps trying. Voice Memos is
    /// quit 2s after Stop, so the file should exist well inside this.
    static let backgroundTimeout: Duration = .seconds(15)

    nonisolated static var voiceMemosDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings", isDirectory: true)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.backgroundColor = NSColor.black.cgColor
        playerLayer = layer
        if let data = defaults.data(forKey: Self.defaultsKey) {
            lastRecording = try? JSONDecoder().decode(LastRecording.self, from: data)
        }
    }

    // MARK: - Derived state

    var activeMedium: RecordingMedium? {
        switch phase {
        case .idle: nil
        case .opening(let medium), .playing(let medium): medium
        case .videoMissing: .video
        }
    }

    var isActive: Bool { phase != .idle }
    var isOpening: Bool {
        if case .opening = phase { return true }
        return false
    }

    var isPlaying: Bool {
        if case .playing = phase { return true }
        return false
    }

    /// True while a recorded video, its spinner or its "missing" message owns
    /// the preview surface. The mirror toggle is disabled for exactly this.
    var isVideoOnSurface: Bool { activeMedium == .video }

    /// Seconds into the current item, 0 when nothing is loaded.
    func currentTime() -> TimeInterval {
        let seconds = player.currentTime().seconds
        return seconds.isFinite ? max(0, seconds) : 0
    }

    var duration: TimeInterval { lastRecording?.duration ?? 0 }

    // MARK: - Recording hand-off

    func recordingFinished(_ finished: FinishedRecording) {
        stop()
        resolveTask?.cancel()
        setLast(LastRecording(
            medium: finished.medium,
            url: finished.url,
            duration: finished.duration,
            notBefore: finished.notBefore
        ))
        playbackLog.notice("last recording is \(finished.medium.rawValue, privacy: .public), \(finished.duration, privacy: .public)s")
        // Start looking for the Voice Memos file now rather than on press, so
        // a later press is usually instant and the lookup is anchored to this
        // recording rather than to whatever is newest by then.
        if finished.medium == .audio {
            resolveTask = Task { [weak self] in
                _ = await self?.resolveAudioURL(timeout: Self.backgroundTimeout)
            }
        }
    }

    // MARK: - Transport

    func play() {
        guard phase == .idle, let last = lastRecording else { return }
        phase = .opening(last.medium)
        playbackLog.notice("opening last \(last.medium.rawValue, privacy: .public)")
        openTask = Task { [weak self] in await self?.open(last) }
    }

    /// Ends playback and, for video, returns the surface to the live camera.
    /// Safe to call in any phase.
    func stop() {
        openTask?.cancel()
        openTask = nil
        endTask?.cancel()
        endTask = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        isPaused = false
        if phase != .idle {
            playbackLog.notice("playback stopped")
        }
        phase = .idle
    }

    func togglePause() {
        guard phase == .playing(.video) else { return }
        if isPaused { player.play() } else { player.pause() }
        isPaused.toggle()
    }

    func seek(to seconds: TimeInterval) {
        guard isPlaying else { return }
        player.seek(
            to: CMTime(seconds: seconds, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    // MARK: - Opening

    private func open(_ last: LastRecording) async {
        let medium = last.medium
        let url: URL?
        switch medium {
        case .audio:
            url = await resolveAudioURL(timeout: Self.pressTimeout)
        case .video:
            url = last.url.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        }
        guard !Task.isCancelled, phase == .opening(medium) else { return }
        guard let url else {
            fail(medium, reason: "file not found")
            return
        }

        let asset = AVURLAsset(url: url)
        let playable = (try? await asset.load(.isPlayable)) ?? false
        guard !Task.isCancelled, phase == .opening(medium) else { return }
        guard playable else {
            fail(medium, reason: "asset not playable")
            return
        }
        if let loaded = try? await asset.load(.duration), loaded.seconds.isFinite, loaded.seconds > 0 {
            updateDuration(loaded.seconds)
        }
        guard !Task.isCancelled, phase == .opening(medium) else { return }

        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        isPaused = false
        phase = .playing(medium)
        player.play()
        playbackLog.notice("playing last \(medium.rawValue, privacy: .public)")

        // Playback ending is the only way out besides the user, and it returns
        // to idle (live camera for video) with no "finished" state.
        endTask = Task { [weak self] in
            let ends = NotificationCenter.default.notifications(
                named: AVPlayerItem.didPlayToEndTimeNotification,
                object: item
            )
            for await _ in ends {
                playbackLog.debug("reached end")
                self?.stop()
                break
            }
        }
    }

    private func fail(_ medium: RecordingMedium, reason: String) {
        playbackLog.error("cannot play last \(medium.rawValue, privacy: .public): \(reason, privacy: .public)")
        switch medium {
        case .video:
            phase = .videoMissing
        case .audio:
            phase = .idle
            onAudioUnavailable?()
        }
        refreshIfMissing()
    }

    // MARK: - Deleted recordings

    /// If the last recording has been deleted (from Photo Booth or Voice
    /// Memos), falls back to the newest movie or memo still on disk, or to
    /// nothing, which disables the play control. Run on panel open and after
    /// a failed open rather than from a file watcher: while the file is there
    /// this costs one stat, and the directory reads happen only once it is
    /// gone.
    func refreshIfMissing() {
        guard phase == .idle || phase == .videoMissing,
              let last = lastRecording, Self.isGone(last)
        else { return }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in await self?.replaceMissing(last) }
    }

    private static func isGone(_ last: LastRecording) -> Bool {
        if let url = last.url { return !FileManager.default.fileExists(atPath: url.path) }
        // Audio not yet matched to a file. Inside the first minute it may
        // still be saving, so it is not treated as deleted.
        return last.notBefore < Date().addingTimeInterval(-60)
    }

    private func replaceMissing(_ last: LastRecording) async {
        // An unmatched memo gets one more look before it counts as gone.
        if last.medium == .audio, last.url == nil,
           await resolveAudioURL(timeout: .zero) != nil {
            return
        }
        let newest = await Self.newestAvailable()
        guard !Task.isCancelled, lastRecording == last else { return }
        guard let newest else {
            playbackLog.notice("last recording deleted, nothing left to play")
            lastRecording = nil
            defaults.removeObject(forKey: Self.defaultsKey)
            return
        }
        let loaded = (try? await AVURLAsset(url: newest.url).load(.duration))?.seconds ?? 0
        guard !Task.isCancelled, lastRecording == last else { return }
        playbackLog.notice("last recording deleted, falling back to \(newest.url.lastPathComponent, privacy: .public)")
        setLast(LastRecording(
            medium: newest.medium,
            url: newest.url,
            duration: loaded.isFinite ? loaded : 0,
            notBefore: newest.created
        ))
    }

    /// The newest `.mov` in Photo Booth's library or `.m4a` in Voice Memos.
    /// A folder that cannot be read counts as empty.
    nonisolated static func newestAvailable() async -> (url: URL, medium: RecordingMedium, created: Date)? {
        let movie = (try? newestFile(in: PhotoBoothLibrary.picturesDirectory, ext: "mov", createdAfter: .distantPast))
            .map { (url: $0.url, medium: RecordingMedium.video, created: $0.created) }
        let memo = (try? newestFile(in: voiceMemosDirectory, ext: "m4a", createdAfter: .distantPast))
            .map { (url: $0.url, medium: RecordingMedium.audio, created: $0.created) }
        switch (movie, memo) {
        case let (movie?, memo?): return movie.created >= memo.created ? movie : memo
        case let (movie?, nil): return movie
        case let (nil, memo?): return memo
        case (nil, nil): return nil
        }
    }

    // MARK: - Voice Memos lookup

    /// Finds the Voice Memos file for the last audio recording, polling until
    /// `timeout` because the `.m4a` appears only after Stop. Returns nil on
    /// timeout or on a read error (which is not retried: a refusal does not
    /// improve with time).
    private func resolveAudioURL(timeout: Duration) async -> URL? {
        guard let last = lastRecording, last.medium == .audio else { return nil }
        if let url = last.url {
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        let notBefore = last.notBefore
        let deadline = ContinuousClock.now + timeout
        while true {
            do {
                if let found = try await Self.newestVoiceMemo(createdAfter: notBefore) {
                    // Only adopt it if this is still the recording we were
                    // asked about; a newer one may have finished meanwhile.
                    guard lastRecording?.notBefore == notBefore else { return nil }
                    playbackLog.notice("found voice memo \(found.lastPathComponent, privacy: .public)")
                    lastRecording?.url = found
                    persist()
                    return found
                }
            } catch {
                playbackLog.error("cannot read Voice Memos recordings: \(error.localizedDescription, privacy: .public)")
                return nil
            }
            guard ContinuousClock.now < deadline, !Task.isCancelled else {
                playbackLog.notice("no voice memo after \(notBefore.description, privacy: .public) yet")
                return nil
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    /// The newest `.m4a` created after `date`. `nonisolated` so the directory
    /// read runs off the main actor.
    nonisolated static func newestVoiceMemo(createdAfter date: Date) async throws -> URL? {
        try newestFile(in: voiceMemosDirectory, ext: "m4a", createdAfter: date)?.url
    }

    nonisolated private static func newestFile(
        in directory: URL, ext: String, createdAfter date: Date
    ) throws -> (url: URL, created: Date)? {
        let keys: [URLResourceKey] = [.creationDateKey]
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )
        var best: (url: URL, created: Date)?
        for url in files where url.pathExtension.lowercased() == ext {
            guard let created = try? url.resourceValues(forKeys: Set(keys)).creationDate,
                  created >= date
            else { continue }
            if let current = best, current.created >= created { continue }
            best = (url, created)
        }
        return best
    }

    // MARK: - Persistence

    private func setLast(_ recording: LastRecording) {
        lastRecording = recording
        persist()
    }

    private func updateDuration(_ seconds: TimeInterval) {
        guard lastRecording != nil else { return }
        lastRecording?.duration = seconds
        persist()
    }

    private func persist() {
        guard let lastRecording, let data = try? JSONEncoder().encode(lastRecording) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
