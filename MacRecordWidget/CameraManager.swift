import AVFoundation
import CoreGraphics
import Observation

/// Display-only camera state for the popover preview.
///
/// This never writes a file and never records. Photo Booth remains the sole
/// capturer; this only drives an `AVCaptureVideoPreviewLayer` so the user can
/// frame a shot before pressing Start.
@MainActor
@Observable
final class CameraManager {

    /// What the preview area should show. Every case except `.running` is a
    /// message state; none of them may block the Start or Stop buttons.
    enum State: Equatable {
        case idle
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

    /// Mirroring is always on, matching Photo Booth. The user-facing toggle was
    /// removed, so the stored preference is deliberately not read: a previously
    /// saved `false` would otherwise strand the preview unmirrored with no way
    /// to change it back.
    let isMirrored = true

    let session = AVCaptureSession()

    private let defaults: UserDefaults
    private let sessionQueue = DispatchQueue(label: "com.macrecordwidget.camera-session")
    private var currentInput: AVCaptureDeviceInput?
    private let observers = ObserverBox()

    private enum Keys {
        static let deviceID = "preview.cameraDeviceID"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDeviceObservers()
    }

    /// The persisted preference. Deliberately NOT cleared when a fallback
    /// happens, so reconnecting the preferred camera restores it.
    private var preferredDeviceID: String? {
        get { defaults.string(forKey: Keys.deviceID) }
        set { defaults.set(newValue, forKey: Keys.deviceID) }
    }

    // MARK: - Lifecycle

    /// Starts the preview, requesting camera access on first use.
    ///
    /// Called when the video toggle turns on and when the popover reopens with
    /// the toggle already on. The session stops when the popover closes, so the
    /// camera activity light cycles with the panel by design.
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

        refreshAvailableCameras()
        guard let device = resolveDevice() else {
            state = .noCamera
            return
        }
        configure(for: device)
    }

    func stop() {
        let session = self.session
        sessionQueue.async { if session.isRunning { session.stopRunning() } }
        state = .idle
        activeCamera = nil
    }

    /// Explicit user pick from the camera menu. This one DOES persist.
    func select(deviceID: String) {
        preferredDeviceID = deviceID
        guard let device = availableCameras.first(where: { $0.uniqueID == deviceID }) else { return }
        configure(for: device)
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

    private func configure(for device: AVCaptureDevice) {
        let session = self.session
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            if let existing = currentInput { session.removeInput(existing) }
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                state = .failed("This camera could not be opened.")
                return
            }
            session.addInput(input)
            session.sessionPreset = .high
            session.commitConfiguration()
            currentInput = input
            activeCamera = device
            applyMirroring()
            // startRunning() blocks, so it never runs on the main thread.
            sessionQueue.async { if !session.isRunning { session.startRunning() } }
            state = .running
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func applyMirroring() {
        guard let connection = session.connections.first(where: { $0.isVideoMirroringSupported }) else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isMirrored
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


/// Holds notification tokens outside the main actor so cleanup can happen in a
/// `deinit`, which is nonisolated and cannot touch main-actor state.
private final class ObserverBox: @unchecked Sendable {
    var tokens: [NSObjectProtocol] = []

    deinit {
        tokens.forEach(NotificationCenter.default.removeObserver)
    }
}
