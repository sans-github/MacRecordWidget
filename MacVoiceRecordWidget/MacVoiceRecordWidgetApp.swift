import SwiftUI

@main
struct MacVoiceRecordWidgetApp: App {
    @StateObject private var recordingManager = RecordingManager()

    var body: some Scene {
        MenuBarExtra {
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
            Image(systemName: recordingManager.isRecording ? "mic.fill" : "mic")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(recordingManager.isRecording ? .green : .primary)
        }
    }
}
