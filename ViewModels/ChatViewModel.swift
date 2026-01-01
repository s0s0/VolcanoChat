import Foundation
import SwiftUI

class ChatViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var imageAttachments: [ImageAttachment] = []  // 图片附件
    @Published var isRecording = false
    var conversationManager = ConversationManager.shared
    private let audioRecorder = AudioRecorder()

    private var currentRecordingURL: URL?

    func sendTextMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let images = imageAttachments

        // 至少要有文本或图片
        guard !text.isEmpty || !images.isEmpty else { return }

        // 清空输入框和图片附件
        inputText = ""
        imageAttachments = []

        Task {
            if images.isEmpty {
                // 纯文本消息
                await conversationManager.sendMessage(text)
            } else {
                // 多模态消息（文本 + 图片）
                await conversationManager.sendMessage(text: text, images: images)
            }
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
