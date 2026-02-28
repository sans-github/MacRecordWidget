import SwiftUI

@main
struct MacVoiceRecordWidgetApp: App {
    @StateObject private var recordingManager = RecordingManager()

    var body: some Scene {
        MenuBarExtra {
            Button {
                recordingManager.startRecording()
            } label: {
                HStack {
                    Image(systemName: "mic.fill")
                    Text("Start")
                }
            }

            Button {
                recordingManager.stopRecording()
            } label: {
                HStack {
                    Text("⏹️  Stop")
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(systemName: "mic.fill")
                .foregroundColor(recordingManager.isRecording ? .green : .primary)
        }
    }
}
