import AVFoundation
import CoreGraphics
import Observation
import os

/// Camera diagnostics. Kept at file scope, not on the class, because the
/// session queue writes to it and a `static let` inside a `@MainActor` type is
/// main-actor isolated under Swift 5.9.
///
/// Watch it live with:
///   log stream --predicate 'subsystem == "com.macrecordwidget"' --info --debug
let cameraLog = Logger(subsystem: "com.macrecordwidget", category: "camera")

enum VideoRecordingError: Error, LocalizedError {
    case cameraNotReady
    case microphoneDenied
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .cameraNotReady:
            return "The camera is not running yet."
        case .microphoneDenied:
            return "Microphone access is turned off for MacRecordWidget, so the video would have no sound."
        case .writeFailed(let reason):
            return reason
        }
    }
}

/// Owns the `AVCaptureSession` behind the always-on preview, and the movie
/// capture that writes into Photo Booth's library.
///
/// The session is configured **once** and kept configured for the app's
/// lifetime. Closing the panel only calls `stopRunning()`, so the camera
/// activity light still cycles with the panel, but reopening does not pay for
/// device discovery, input creation and format negotiation all over again.
@MainActor
@Observable
final class CameraManager {

    /// What the preview area should show. Every case except `.running` is a
    /// message state; none of them may block the audio Start or Stop buttons.
    enum State: Equatable {
        case idle
        /// Session is coming up. Held until the first frame actually arrives,
        /// so the preview shows a spinner rather than a black layer: setting
        /// `.running` when `startRunning()` was merely *dispatched* is what
        /// made the panel look frozen for 2-3 seconds.
        case starting
        case running
        case notDetermined
        case denied
        case restricted
        case noCamera
        case failed(String)
    }

    /// Width of the shipped button row, kept as one named constant so the
    /// anchor can be flipped in one place if hardware testing demands it.
    static let rowWidth: CGFloat = 200

    private(set) var state: State = .idle
    private(set) var availableCameras: [AVCaptureDevice] = []

    /// The device actually feeding the preview layer, which is not necessarily
    /// the persisted preference: after a fallback these differ on purpose.
    private(set) var activeCamera: AVCaptureDevice?

    /// True between `startRecording()` succeeding and the file being closed.
    private(set) var isRecordingVideo = false

    /// Mirroring is off: the preview and the saved movie show the scene the way
    /// everyone else sees it, not the selfie flip. Text held up to the camera
    /// reads correctly. There is no user-facing toggle, so the stored
    /// preference is deliberately not read.
    let isMirrored = false

    let session = AVCaptureSession()

    /// The one and only preview layer, owned here and never deallocated.
    ///
    /// This is a deadlock fix, not a tidiness choice. `AVCaptureVideoPreviewLayer`
    /// calls `setSession:nil` from its own `dealloc`, which runs inside a
    /// CoreAnimation transaction on the **main thread** and takes the session
    /// lock. If the session queue is inside `commitConfiguration()` at that
    /// moment, it is in turn waiting on the main thread (via
    /// `AVCaptureMovieFileOutput`'s `performSelector:onThread:waitUntilDone:`)
    /// and the app hangs with no way out but being killed. Measured from a
    /// `sample` of a hung build on 2026-09-10.
    ///
    /// A layer that is created once and outlives the app cannot dealloc, so
    /// that side of the deadlock cannot happen. The view therefore stays
    /// mounted at all times and message states are drawn *over* it, rather than
    /// swapped in for it.
    let previewLayer = AVCaptureVideoPreviewLayer()

    private let defaults: UserDefaults
    private let sessionQueue = DispatchQueue(label: "com.macrecordwidget.camera-session")
    private let movieOutput = AVCaptureMovieFileOutput()
    private let frameOutput = AVCaptureVideoDataOutput()
    private let frameWatcher = FirstFrameWatcher()
    private let recordingDelegate = MovieRecordingDelegate()

    /// Mirror of `session.isRunning`, maintained here so the main thread never
    /// has to ask the session anything.
    ///
    /// Every `AVCaptureSession` property access takes the session's internal
    /// lock, and `startRunning()` holds that lock for as long as the device
    /// takes to come up. On a contended external camera that is unbounded, so
    /// reading `session.isRunning` from the main thread could freeze the entire
    /// app with no way out but killing it. Nothing on the main actor may touch
    /// `session` or `movieOutput` directly.
    private var isSessionRunning = false

    /// Fails the start instead of spinning forever. See `startWatchdog`.
    private var watchdog: Task<Void, Never>?
    private var startedStartingAt: Date?

    /// How long the camera gets to produce its first frame before the preview
    /// gives up and offers a retry. Warm starts are well under a second; a cold
    /// external USB camera has been seen to take several.
    private static let startTimeoutSeconds: UInt64 = 10

    private var currentInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private let observers = ObserverBox()

    private enum Keys {
        static let deviceID = "preview.cameraDeviceID"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        frameOutput.alwaysDiscardsLateVideoFrames = true
        // Safe here and only here: the session has no clients yet, so nothing
        // can be holding its lock.
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        registerDeviceObservers()
        frameWatcher.onFirstFrame = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.state == .starting else { return }
                let waited = self.startedStartingAt.map { Date().timeIntervalSince($0) } ?? -1
                cameraLog.notice("first frame after \(waited, format: .fixed(precision: 2))s")
                self.watchdog?.cancel()
                self.watchdog = nil
                self.state = .running
            }
        }
        frameOutput.setSampleBufferDelegate(frameWatcher, queue: frameWatcher.queue)
    }

    /// The persisted preference. Deliberately NOT cleared when a fallback
    /// happens, so reconnecting the preferred camera restores it.
    private var preferredDeviceID: String? {
        get { defaults.string(forKey: Keys.deviceID) }
        set { defaults.set(newValue, forKey: Keys.deviceID) }
    }

    /// Whether the video record button can do anything right now.
    var canRecordVideo: Bool { state == .running && !isRecordingVideo }

    /// Why the video button is unavailable, for its tooltip. `nil` when it is
    /// available. Mirrors the message states the preview area already renders,
    /// so the button and the preview never disagree about what is wrong.
    var videoUnavailableReason: String? {
        switch state {
        case .running: return nil
        case .idle, .starting, .notDetermined: return "Waiting for the camera…"
        case .denied: return "Camera access is turned off for MacRecordWidget"
        case .restricted: return "Camera access is restricted on this Mac"
        case .noCamera: return "No camera connected"
        case .failed(let reason): return reason
        }
    }

    // MARK: - Lifecycle

    /// Brings the preview up, requesting camera access on first use.
    ///
    /// Called when the panel opens. After the first call the session is already
    /// configured, so this is just `startRunning()`.
    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            state = .notDetermined
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                state = .denied
                return
            }
        case .denied:
            state = .denied
            return
        case .restricted:
            // Restricted is not denied: it is MDM or parental controls, and no
            // Settings pane the user can reach will change it, so the UI must
            // not offer an "Open Settings" action here.
            state = .restricted
            return
        @unknown default:
            state = .failed("Unknown camera authorization status.")
            return
        }

        if isConfigured {
            cameraLog.debug("start: session already configured, resuming")
            resumeRunning()
            return
        }

        beginStarting("first configure")
        refreshAvailableCameras()
        cameraLog.notice("discovered \(self.availableCameras.count) camera(s)")
        guard let device = resolveDevice() else {
            cameraLog.error("start: no camera resolved")
            state = .noCamera
            return
        }
        configure(for: device)
    }

    /// Stops delivering frames without tearing the session down.
    ///
    /// The inputs, outputs and negotiated format all stay in place, so the next
    /// `start()` skips straight to `startRunning()`. Callers must not invoke
    /// this while `isRecordingVideo` is true: the movie file lives inside this
    /// session and stopping it mid-write truncates the recording.
    func pause() {
        guard !isRecordingVideo else { return }
        cameraLog.debug("pause")
        watchdog?.cancel()
        watchdog = nil
        isSessionRunning = false
        let session = self.session
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
                cameraLog.debug("pause: stopped")
            }
        }
        state = isConfigured ? .starting : .idle
        frameWatcher.rearm()
    }

    private func resumeRunning() {
        // Already delivering frames: this is the panel reopening on a session
        // that never stopped, which is what happens while a video recording is
        // in progress. Going through `.starting` would flash a spinner over a
        // live recording.
        //
        // This asks the cached flag, never the session: see `isSessionRunning`.
        guard !isSessionRunning else {
            state = .running
            return
        }
        beginStarting("resume")
        frameWatcher.rearm()
        let session = self.session
        sessionQueue.async { [weak self] in
            let began = Date()
            if !session.isRunning { session.startRunning() }
            let elapsed = Date().timeIntervalSince(began)
            cameraLog.notice("startRunning returned after \(elapsed, format: .fixed(precision: 2))s")
            Task { @MainActor [weak self] in self?.isSessionRunning = true }
        }
    }

    /// Enters `.starting` and arms the watchdog.
    private func beginStarting(_ reason: String) {
        cameraLog.notice("starting camera (\(reason, privacy: .public))")
        state = .starting
        startedStartingAt = Date()
        startWatchdog()
    }

    /// Turns "spinner forever" into a failure the user can act on.
    ///
    /// There is no timeout anywhere in `AVCaptureSession`: if the device never
    /// produces a frame, `startRunning()` simply never leads anywhere and the
    /// preview sits on "Starting camera…" until the app is killed. This bounds
    /// that wait.
    private func startWatchdog() {
        watchdog?.cancel()
        watchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.startTimeoutSeconds * 1_000_000_000)
            guard !Task.isCancelled, let self, self.state == .starting else { return }
            let name = self.activeCamera?.localizedName ?? "unknown"
            cameraLog.error("no frame within \(Self.startTimeoutSeconds)s from \(name, privacy: .public)")
            self.state = .failed(
                "The camera did not start. It may be in use by another app, or need unplugging and plugging back in."
            )
        }
    }

    /// Tears the session's inputs back down and rebuilds them from scratch.
    /// Reachable from the failure state's Retry button.
    func retry() {
        guard !isRecordingVideo else { return }
        cameraLog.notice("retry requested")
        watchdog?.cancel()
        watchdog = nil
        let session = self.session
        sessionQueue.async { if session.isRunning { session.stopRunning() } }
        isSessionRunning = false
        frameWatcher.rearm()
        refreshAvailableCameras()
        guard let device = resolveDevice() else {
            state = .noCamera
            return
        }
        configure(for: device)
    }

    /// Explicit user pick from the camera menu. This one DOES persist.
    func select(deviceID: String) {
        // Reconfiguring mid-recording would break the file being written. The
        // picker is disabled while recording, so this is a backstop.
        guard !isRecordingVideo else { return }
        preferredDeviceID = deviceID
        guard let device = availableCameras.first(where: { $0.uniqueID == deviceID }) else { return }
        configure(for: device)
    }

    // MARK: - Recording

    /// Starts writing a movie into Photo Booth's library.
    ///
    /// The microphone input is added here rather than at session setup, so that
    /// simply opening the panel never triggers a mic permission prompt: the
    /// prompt arrives the first time the user actually records video. This runs
    /// inside the arming window, where a brief reconfiguration is invisible.
    func startRecording() async throws {
        guard state == .running, !isRecordingVideo else {
            throw VideoRecordingError.cameraNotReady
        }

        try await attachMicrophoneIfNeeded()

        do {
            try PhotoBoothLibrary.ensurePicturesDirectoryExists()
        } catch {
            throw VideoRecordingError.writeFailed(
                "Could not open the Photo Booth library folder. \(error.localizedDescription)"
            )
        }

        let url = PhotoBoothLibrary.availableMovieURL()
        let session = self.session
        let movieOutput = self.movieOutput
        let delegate = self.recordingDelegate
        let mirrored = isMirrored
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                Self.applyMirroring(session: session, movieOutput: movieOutput, mirrored: mirrored)
                movieOutput.startRecording(to: url, recordingDelegate: delegate)
                continuation.resume()
            }
        }
        cameraLog.notice("video recording started")
        isRecordingVideo = true
    }

    /// Stops the movie and waits for the file to be closed.
    ///
    /// The wait is the point: `AVCaptureMovieFileOutput` finishes writing
    /// asynchronously, and a `.mov` whose process died before the completion
    /// callback is unplayable. Returns the finished file's URL.
    @discardableResult
    func stopRecording() async -> URL? {
        guard isRecordingVideo else { return nil }
        let result = await recordingDelegate.finish(movieOutput, on: sessionQueue)
        isRecordingVideo = false
        cameraLog.notice("video recording stopped, file \(result == nil ? "missing" : "written", privacy: .public)")

        guard let url = result else { return nil }
        // Only now does the movie join Photo Booth's filmstrip; indexing a file
        // that is still being written would list a movie that cannot play.
        PhotoBoothLibrary.addToFilmstrip(url)
        return url
    }

    private func attachMicrophoneIfNeeded() async throws {
        guard audioInput == nil else { return }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .audio) else {
                throw VideoRecordingError.microphoneDenied
            }
        case .denied, .restricted:
            throw VideoRecordingError.microphoneDenied
        @unknown default:
            throw VideoRecordingError.microphoneDenied
        }

        guard let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        let session = self.session
        let added: Bool = await withCheckedContinuation { continuation in
            sessionQueue.async {
                session.beginConfiguration()
                let ok = session.canAddInput(input)
                if ok { session.addInput(input) }
                session.commitConfiguration()
                continuation.resume(returning: ok)
            }
        }
        if added { audioInput = input }
    }

    // MARK: - Session

    private func refreshAvailableCameras() {
        availableCameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices
    }

    /// Preferred device if present, otherwise the system default. The stored
    /// preference is left untouched so a reconnect restores it.
    private func resolveDevice() -> AVCaptureDevice? {
        if let id = preferredDeviceID,
           let match = availableCameras.first(where: { $0.uniqueID == id }) {
            return match
        }
        return AVCaptureDevice.default(for: .video) ?? availableCameras.first
    }

    /// Builds or rebuilds the session for `device`.
    ///
    /// Everything expensive happens on `sessionQueue`, never on the main actor:
    /// `AVCaptureDeviceInput(device:)` opens the hardware and
    /// `commitConfiguration()` negotiates a format, and both used to block the
    /// panel's first paint. Only the resulting state lands back on the main
    /// actor.
    private func configure(for device: AVCaptureDevice) {
        beginStarting("configure \(device.localizedName)")
        frameWatcher.rearm()

        let mirrored = isMirrored
        let session = self.session
        let movieOutput = self.movieOutput
        let frameOutput = self.frameOutput
        let previousInput = currentInput
        let needsOutputs = !isConfigured

        sessionQueue.async { [weak self] in
            let input: AVCaptureDeviceInput
            do {
                input = try AVCaptureDeviceInput(device: device)
            } catch {
                let message = error.localizedDescription
                cameraLog.error("could not open input: \(message, privacy: .public)")
                Task { @MainActor [weak self] in self?.state = .failed(message) }
                return
            }

            session.beginConfiguration()
            if let previousInput { session.removeInput(previousInput) }
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                cameraLog.error("session refused the input")
                Task { @MainActor [weak self] in
                    self?.state = .failed("This camera could not be opened.")
                }
                return
            }
            session.addInput(input)
            session.sessionPreset = .high

            if needsOutputs {
                if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }
                // Present purely to detect the first frame, so the preview can
                // hold a "Starting camera…" state instead of showing black.
                if session.canAddOutput(frameOutput) { session.addOutput(frameOutput) }
            }
            session.commitConfiguration()
            // Mirroring is set here, on the session queue, for the same reason
            // nothing else touches the session from the main actor.
            Self.applyMirroring(session: session, movieOutput: movieOutput, mirrored: mirrored)

            let began = Date()
            if !session.isRunning { session.startRunning() }
            let elapsed = Date().timeIntervalSince(began)
            cameraLog.notice("startRunning returned after \(elapsed, format: .fixed(precision: 2))s")

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentInput = input
                self.activeCamera = device
                self.isConfigured = true
                self.isSessionRunning = true
            }
        }
    }

    /// Applies the mirroring setting to the preview and to the movie output, so
    /// the saved file matches what the preview showed.
    ///
    /// `nonisolated static` on purpose: every call site is the session queue.
    /// Connection properties take the session lock, and taking that lock on the
    /// main thread is what could freeze the app.
    nonisolated private static func applyMirroring(
        session: AVCaptureSession,
        movieOutput: AVCaptureMovieFileOutput,
        mirrored: Bool
    ) {
        for connection in session.connections where connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
        if let movieConnection = movieOutput.connection(with: .video),
           movieConnection.isVideoMirroringSupported {
            movieConnection.automaticallyAdjustsVideoMirroring = false
            movieConnection.isVideoMirrored = mirrored
        }
    }

    // MARK: - Hot plug

    private func registerDeviceObservers() {
        let center = NotificationCenter.default
        let handle: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor [weak self] in await self?.handleDeviceChange() }
        }
        observers.tokens = [
            center.addObserver(forName: .AVCaptureDeviceWasConnected, object: nil, queue: .main, using: handle),
            center.addObserver(forName: .AVCaptureDeviceWasDisconnected, object: nil, queue: .main, using: handle)
        ]
    }

    /// On disconnect, fall back without discarding the preference. On reconnect,
    /// the preferred camera is picked up again by `resolveDevice()`.
    private func handleDeviceChange() async {
        guard state != .idle else { return }
        // A rebuild mid-recording would truncate the movie. The disconnect is
        // handled when the recording ends.
        guard !isRecordingVideo else { return }
        refreshAvailableCameras()
        guard !availableCameras.isEmpty else {
            state = .noCamera
            activeCamera = nil
            return
        }
        let stillPresent = activeCamera.map { active in
            availableCameras.contains { $0.uniqueID == active.uniqueID }
        } ?? false
        let preferredIsBack = preferredDeviceID.map { id in
            availableCameras.contains { $0.uniqueID == id }
        } ?? false
        if !stillPresent || preferredIsBack, let device = resolveDevice() {
            configure(for: device)
        }
    }
}


/// Flips the preview out of its "starting" state the moment a real frame
/// arrives.
///
/// There is no callback for "the preview layer has something to draw", and
/// `startRunning()` returning is not the same thing, so the only honest signal
/// is a sample buffer. After the first one this does nothing but check a flag.
private final class FirstFrameWatcher: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.macrecordwidget.first-frame")

    var onFirstFrame: (() -> Void)?
    private var hasSeenFrame = false

    /// Called when the session is about to come up again, so the next frame
    /// counts as the first one.
    func rearm() {
        queue.async { self.hasSeenFrame = false }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !hasSeenFrame else { return }
        hasSeenFrame = true
        onFirstFrame?()
    }
}


/// Bridges `AVCaptureFileOutputRecordingDelegate` to async/await, so callers
/// can await the file actually being closed.
private final class MovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL?, Never>?

    /// Stops `output` and returns once the file is finalised, or immediately if
    /// it was not recording.
    /// `queue` is the session queue: `isRecording` and `stopRecording()` both
    /// take the session lock, which must never be taken on the main thread.
    func finish(_ output: AVCaptureMovieFileOutput, on queue: DispatchQueue) async -> URL? {
        return await withCheckedContinuation { continuation in
            queue.async {
                guard output.isRecording else {
                    continuation.resume(returning: nil)
                    return
                }
                self.lock.lock()
                self.continuation = continuation
                self.lock.unlock()
                output.stopRecording()
            }
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        // A non-nil error can still leave a playable file, but treat it as a
        // failure for indexing purposes: a broken entry in Photo Booth's
        // filmstrip is worse than a movie that is merely present on disk.
        pending?.resume(returning: error == nil ? outputFileURL : nil)
    }
}


/// Holds notification tokens outside the main actor so cleanup can happen in a
/// `deinit`, which is nonisolated and cannot touch main-actor state.
private final class ObserverBox: @unchecked Sendable {
    var tokens: [NSObjectProtocol] = []

    deinit {
        tokens.forEach(NotificationCenter.default.removeObserver)
    }
}
