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
        }

        isRecording = true
    }

    func stopRecording() {
        if let url = URL(string: "shortcuts://run-shortcut?name=Stop") {
            NSWorkspace.shared.open(url)
        }
        isRecording = false
    }
}
