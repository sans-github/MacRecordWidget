import SwiftUI

@main
struct MacRecordWidgetApp: App {
    @StateObject private var recordingManager = RecordingManager()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle("Include Video", isOn: $recordingManager.videoEnabled)
                        .toggleStyle(.switch)
                        .disabled(recordingManager.isRecording)
                    Spacer()
                    Button {
                        if recordingManager.isRecording {
                            recordingManager.stopRecording()
                        }
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                VStack(spacing: 6) {
                    Button {
                        recordingManager.startRecording()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NSStatusBar.system.statusItems.first?.button?.performClick(nil)
                        }
                    } label: {
                        Label("Start", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(recordingManager.isRecording)

                    Button {
                        recordingManager.stopRecording()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NSStatusBar.system.statusItems.first?.button?.performClick(nil)
                        }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!recordingManager.isRecording)
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .frame(width: 180)
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
