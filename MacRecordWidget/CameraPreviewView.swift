import AVFoundation
import SwiftUI

/// macOS 14 has no SwiftUI-native camera preview, so the live image has to come
/// from an `AVCaptureVideoPreviewLayer` hosted in AppKit.
@MainActor
struct CameraPreviewLayerView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = preview
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView.layer as? AVCaptureVideoPreviewLayer)?.session = session
    }
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
            if camera.state == .running {
                CameraPreviewLayerView(session: camera.session)
            } else {
                messageView
                    .padding(.horizontal, 16)
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
            Image(systemName: symbolName)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
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
/// the two camera controls sit together. The mirror checkbox was removed;
/// mirroring is now always on.
@MainActor
struct CameraControls: View {
    @Bindable var camera: CameraManager
    let scale: PanelScale

    var body: some View {
        HStack(spacing: 8) {
            // The picker's selected value is also the camera-name indicator: it
            // names the device actually feeding the layer, which after a
            // fallback is not the persisted preference.
            Picker("Camera", selection: cameraSelection) {
                if camera.availableCameras.isEmpty {
                    Text("No camera").tag("")
                }
                ForEach(camera.availableCameras, id: \.uniqueID) { device in
                    Text(device.localizedName)
                        .font(scale.controlFont)
                        .tag(device.uniqueID)
                }
            }
            .labelsHidden()
            .font(scale.controlFont)
            .controlSize(scale.controlSize)
            .frame(maxWidth: scale.pickerMaxWidth)
            .disabled(camera.availableCameras.isEmpty)
            .accessibilityLabel("Preview camera")
            .accessibilityIdentifier("cameraPicker")

        }
    }

    private var cameraSelection: Binding<String> {
        Binding(
            get: { camera.activeCamera?.uniqueID ?? "" },
            set: { id in if !id.isEmpty { camera.select(deviceID: id) } }
        )
    }
}
