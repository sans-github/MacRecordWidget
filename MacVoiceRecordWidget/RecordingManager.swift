import Foundation
import SwiftUI
import AVFoundation

class RecordingManager: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    @Published var isRecording = false
    @Published var videoEnabled = false {
        didSet { if videoEnabled { setupCaptureSessionIfNeeded() } }
    }

    private var captureSession: AVCaptureSession?
    private var fileOutput: AVCaptureMovieFileOutput?

    private func setupCaptureSessionIfNeeded() {
        guard captureSession == nil else { return }
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(for: .video),
              let mic = AVCaptureDevice.default(for: .audio),
              let videoInput = try? AVCaptureDeviceInput(device: camera),
              let audioInput = try? AVCaptureDeviceInput(device: mic),
              session.canAddInput(videoInput),
              session.canAddInput(audioInput) else { return }

        session.addInput(videoInput)
        session.addInput(audioInput)

        let output = AVCaptureMovieFileOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        captureSession = session
        fileOutput = output
    }

    func startRecording() {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let name = "Recording-\(timestamp)"

        if let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "shortcuts://run-shortcut?name=Start&input=text&text=\(encoded)") {
            NSWorkspace.shared.open(url)
        }

        if videoEnabled, let session = captureSession, let output = fileOutput {
            let moviesURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
            let fileURL = moviesURL.appendingPathComponent("\(name).mov")
            session.startRunning()
            output.startRecording(to: fileURL, recordingDelegate: self)
        }

        isRecording = true
    }

    func stopRecording() {
        if let url = URL(string: "shortcuts://run-shortcut?name=Stop") {
            NSWorkspace.shared.open(url)
        }

        if videoEnabled {
            fileOutput?.stopRecording()
            captureSession?.stopRunning()
        }

        isRecording = false
    }

    // AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {}
}
