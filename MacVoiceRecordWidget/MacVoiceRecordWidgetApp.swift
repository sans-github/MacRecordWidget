import SwiftUI

@main
struct MacVoiceRecordWidgetApp: App {
    @StateObject private var recordingManager = RecordingManager()

    var body: some Scene {
        MenuBarExtra {
            Toggle(isOn: $recordingManager.videoEnabled) {
                Label("Include Video", systemImage: "camera")
            }
            .disabled(recordingManager.isRecording)

            Divider()

            Button {
                recordingManager.startRecording()
            } label: {
                Label("Start", systemImage: "mic.fill")
            }
            .disabled(recordingManager.isRecording)

            Button {
                recordingManager.stopRecording()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .disabled(!recordingManager.isRecording)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            let icon = recordingManager.videoEnabled
                ? (recordingManager.isRecording ? "video.fill" : "video")
                : (recordingManager.isRecording ? "mic.fill" : "mic")
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(recordingManager.isRecording ? .green : .primary)
        }
    }
}
