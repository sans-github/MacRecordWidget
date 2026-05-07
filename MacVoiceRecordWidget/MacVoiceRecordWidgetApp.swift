import SwiftUI

@main
struct MacVoiceRecordWidgetApp: App {
    @StateObject private var recordingManager = RecordingManager()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Include Video", isOn: $recordingManager.videoEnabled)
                    .toggleStyle(.switch)
                    .disabled(recordingManager.isRecording)

                Divider()

                HStack(spacing: 8) {
                    Button {
                        recordingManager.startRecording()
                    } label: {
                        Label("Start", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(recordingManager.isRecording)

                    Button {
                        recordingManager.stopRecording()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!recordingManager.isRecording)
                }
                .buttonStyle(.borderedProminent)

                Divider()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(12)
            .frame(width: 220)
        } label: {
            let icon = recordingManager.videoEnabled
                ? (recordingManager.isRecording ? "video.fill" : "video")
                : (recordingManager.isRecording ? "mic.fill" : "mic")
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(recordingManager.isRecording ? .green : .primary)
        }
        .menuBarExtraStyle(.window)
    }
}
