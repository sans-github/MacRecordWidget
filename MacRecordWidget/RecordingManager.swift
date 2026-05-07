import Foundation
import SwiftUI

class RecordingManager: ObservableObject {
    @Published var isRecording = false
    @Published var videoEnabled = false

    func startRecording() {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let name = "Recording-\(timestamp)"

        if let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "shortcuts://run-shortcut?name=Start&input=text&text=\(encoded)") {
            NSWorkspace.shared.open(url)
        }

        if videoEnabled {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Photo Booth.app"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let task = Process()
                task.launchPath = "/usr/bin/osascript"
                task.arguments = ["-e",
                    "tell application \"System Events\" to tell process \"Photo Booth\" to set value of attribute \"AXFullScreen\" of window 1 to true"
                ]
                try? task.run()
            }
        }

        isRecording = true
    }

    func stopRecording() {
        if let url = URL(string: "shortcuts://run-shortcut?name=Stop") {
            NSWorkspace.shared.open(url)
        }
        if videoEnabled {
            NSWorkspace.shared.runningApplications
                .first(where: { $0.bundleIdentifier == "com.apple.PhotoBooth" })?
                .terminate()
        }
        isRecording = false
    }
}
