import Foundation
import SwiftUI

class ChatViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var isRecording = false
    var conversationManager = ConversationManager.shared
    private let audioRecorder = AudioRecorder()

    private var currentRecordingURL: URL?

    func sendTextMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let message = inputText
        inputText = ""

        Task {
            await conversationManager.sendMessage(message)
        }
    }

    func startRecording() {
        audioRecorder.requestPermission { [weak self] granted in
            guard granted else {
                print("Microphone permission denied")
                return
            }

            DispatchQueue.main.async {
                self?.isRecording = true
                if let url = self?.audioRecorder.startRecording() {
                    self?.currentRecordingURL = url
                }
            }
        }
    }

    func stopRecording() {
        isRecording = false
        if let url = audioRecorder.stopRecording() {
            Task {
                await conversationManager.sendVoiceMessage(audioURL: url)
            }
        }
        currentRecordingURL = nil
    }

    @MainActor
    func clearConversation() {
        conversationManager.clearConversation()
    }
}
