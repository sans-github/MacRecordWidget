import AVFoundation
import SwiftUI

/// macOS 14 has no SwiftUI-native camera preview, so the live image has to come
/// from an `AVCaptureVideoPreviewLayer` hosted in AppKit.
///
/// The layer is **not** created here. It is owned by `CameraManager` for the
/// app's lifetime, because a preview layer that deallocates takes the session
/// lock on the main thread and can deadlock against the session queue. See the
/// comment on `CameraManager.previewLayer`.
@MainActor
struct CameraPreviewLayerView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        previewLayer.frame = view.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = previewLayer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// The preview block below the button row: either the live image or a message
/// state. Its controls live in the button row, not here.
@MainActor
struct CameraPreviewPanel: View {
    @Bindable var camera: CameraManager
    let scale: PanelScale

    /// Matches the rounding of the `MenuBarExtra` panel itself. The preview runs
    /// flush to the panel's left, right and bottom edges, so only its bottom
    /// corners are rounded; square ones would poke out past the window.
    private static let panelCornerRadius: CGFloat = 10

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .underPageBackgroundColor))
            // Mounted unconditionally: unmounting it would deallocate the
            // shared preview layer, which is one half of a main-thread deadlock
            // against the session queue. Message states are drawn over it on an
            // opaque background instead.
            CameraPreviewLayerView(previewLayer: camera.previewLayer)
                .opacity(camera.state == .running ? 1 : 0)
            if camera.state != .running {
                ZStack {
                    Rectangle()
                        .fill(Color(nsColor: .underPageBackgroundColor))
                    messageView
                        .padding(.horizontal, 16)
                }
            }
        }
        .frame(width: scale.previewWidth, height: scale.previewHeight)
        .clipShape(
            .rect(
                bottomLeadingRadius: Self.panelCornerRadius,
                bottomTrailingRadius: Self.panelCornerRadius
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera preview")
        .accessibilityIdentifier("cameraPreview")
    }

    // MARK: - States

    @ViewBuilder
    private var messageView: some View {
        VStack(spacing: 6) {
            if camera.state == .starting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // Restricted deliberately gets no button: the Settings pane cannot
            // resolve an MDM or parental-controls restriction.
            if camera.state == .denied {
                Button("Open Settings") { openCameraSettings() }
                    .font(.system(size: 12))
                    .accessibilityIdentifier("openCameraSettingsButton")
            }
            // The failure state is reachable from the start watchdog, so it has
            // to offer a way back: a spinner that never resolves and no button
            // is the state this bug used to leave the panel in.
            if case .failed = camera.state {
                Button("Try Again") { camera.retry() }
                    .font(.system(size: 12))
                    .accessibilityIdentifier("retryCameraButton")
            }
        }
    }

    private var symbolName: String {
        switch camera.state {
        case .denied, .restricted: "lock.fill"
        case .noCamera: "video.slash"
        case .failed: "exclamationmark.triangle"
        default: "video"
        }
    }

    private var message: String {
        switch camera.state {
        case .idle, .running: ""
        // Held until a real frame arrives, not until startRunning() is
        // dispatched. Camera warm-up is a second or more of nothing, and a
        // silent black rectangle for that long reads as broken.
        case .starting: "Starting camera…"
        case .notDetermined: "Waiting for camera access…"
        case .denied: "Camera access is turned off for MacRecordWidget."
        case .restricted: "Camera access is restricted on this Mac and cannot be changed here."
        case .noCamera: "No camera connected."
        case .failed(let reason): reason
        }
    }

    private func openCameraSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

}


/// The camera picker, mounted in the button row next to the camera toggle so
/// the two camera controls sit together. Mirroring is not here: it lives in
/// the button row beside the video record button, as a toggle.
@MainActor
struct CameraControls: View {
    let camera: CameraManager
    let scale: PanelScale

    var body: some View {
        HStack(spacing: 8) {
            // A Menu of Buttons, deliberately NOT a `Picker`. A Picker needs a
            // two-way binding, and the only honest source of truth for "which
            // camera is live" is `activeCamera`, which `configure()` updates
            // asynchronously from the session queue. SwiftUI's NSPopUpButton
            // reads that binding back on its next update pass, still sees the
            // previous device, and writes it back as a second `select()` --
            // which switched the camera and then silently switched it back
            // about two seconds later. Buttons are one-way commands: there is
            // no getter to read back and nothing to write back.
            //
            // The label still names the device actually feeding the layer,
            // which after a fallback is not the persisted preference.
            Menu {
                ForEach(camera.availableCameras, id: \.uniqueID) { device in
                    Button {
                        camera.select(deviceID: device.uniqueID)
                    } label: {
                        if device.uniqueID == camera.activeCamera?.uniqueID {
                            Label(device.localizedName, systemImage: "checkmark")
                        } else {
                            Text(device.localizedName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(camera.activeCamera?.localizedName ?? "No camera")
                        .font(scale.controlFont)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    // The chevron sits in a green well rather than being drawn
                    // by the popup button itself. Green because the menu picks
                    // the camera, which is the same subsystem the video, mirror
                    // and S/M/L controls belong to.
                    //
                    // This is why the native indicator is hidden and the label
                    // is drawn by hand: an NSPopUpButton's own chevron cannot be
                    // tinted separately from its content.
                    Image(systemName: "chevron.down")
                        .font(scale.chevronFont)
                        .foregroundStyle(RowPalette.glyphOn)
                        .frame(width: scale.chevronWellWidth, height: scale.glyphSize)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(RowPalette.video)
                        )
                }
                .padding(.leading, 7)
                .padding(.trailing, 4)
                .frame(height: scale.controlHeight)
                // The same off-state chrome as every toggle in the row: the
                // menu is never "on", so it is always the outlined rounded
                // rect. Keeping the container matters more here than anywhere
                // else -- without it a menu stops looking like a menu.
                .background(
                    CapsuleControlBackground(
                        scale: scale,
                        isOn: false,
                        tint: RowPalette.video,
                        ember: nil
                    )
                )
                .contentShape(Rectangle())
            }
            // `.button` + `.plain` + a hidden indicator, so what is drawn is
            // exactly the label above and nothing else. It is still a Menu of
            // Buttons underneath -- see the comment above; it must not become a
            // Picker.
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .font(scale.controlFont)
            .controlSize(scale.controlSize)
            .frame(maxWidth: scale.pickerMaxWidth)
            .disabled(camera.availableCameras.isEmpty)
            .accessibilityLabel("Preview camera")
            .accessibilityIdentifier("cameraPicker")

        }
    }
}
