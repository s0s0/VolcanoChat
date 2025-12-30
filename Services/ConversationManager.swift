import Foundation

class ConversationManager: ObservableObject {
    static let shared = ConversationManager()

    @Published var conversation: Conversation
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let llmService = VolcanoLLMService.shared
    private let asrService = VolcanoASRService.shared
    private let ttsService = VolcanoTTSService.shared
    private let audioPlayer = AudioPlayer()

    var autoPlayResponse: Bool {
        get { UserDefaults.standard.bool(forKey: "autoPlayResponse") }
        set { UserDefaults.standard.set(newValue, forKey: "autoPlayResponse") }
    }

    var enableWebSearch: Bool {
        get { UserDefaults.standard.bool(forKey: "enableWebSearch") }
        set { UserDefaults.standard.set(newValue, forKey: "enableWebSearch") }
    }

    private init() {
        self.conversation = Conversation()
        // 默认开启语音播报
        if UserDefaults.standard.object(forKey: "autoPlayResponse") == nil {
            UserDefaults.standard.set(true, forKey: "autoPlayResponse")
        }
        // 默认关闭联网搜索
        if UserDefaults.standard.object(forKey: "enableWebSearch") == nil {
            UserDefaults.standard.set(false, forKey: "enableWebSearch")
        }
    }

    func sendMessage(_ content: String) async {
        let userMessage = Message(role: .user, content: content)
        await MainActor.run {
            conversation.addMessage(userMessage)
        }

        await generateResponse()
    }

    func sendVoiceMessage(audioURL: URL) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            // 语音转文字
            let recognizedText = try await asrService.recognizeSpeech(audioURL: audioURL)

            if recognizedText.isEmpty {
                await MainActor.run {
                    errorMessage = "无法识别语音内容"
                    isLoading = false
                }
                return
            }

            // 添加用户消息
            let userMessage = Message(role: .user, content: recognizedText)
            await MainActor.run {
                conversation.addMessage(userMessage)
            }

            // 生成回复
            await generateResponse()
        } catch {
            await MainActor.run {
                errorMessage = "语音识别失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func generateResponse() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        // 创建一个空的助手消息
        let assistantMessage = Message(role: .assistant, content: "")
        await MainActor.run {
            conversation.addMessage(assistantMessage)
        }

        // 过滤掉空的消息（只发送有内容的消息给 LLM）
        var messagesToSend = conversation.messages.filter { !$0.content.isEmpty }

        // 如果配置了 system prompt，在消息列表开头插入 system 消息（不保存到 conversation 中，只发送给 LLM）
        let systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? ""
        if !systemPrompt.isEmpty {
            let systemMessage = Message(role: .system, content: systemPrompt)
            messagesToSend.insert(systemMessage, at: 0)
        }

        do {
            // 使用流式响应，并根据设置启用联网搜索
            try await llmService.chatStream(messages: messagesToSend, enableWebSearch: enableWebSearch) { [weak self] chunk in
                guard let self = self else { return }

                Task { @MainActor in
                    // 收到第一个 chunk 时立即隐藏"正在思考..."
                    if self.isLoading {
                        self.isLoading = false
                    }

                    // 更新最后一条消息的内容
                    if let lastIndex = self.conversation.messages.indices.last {
                        self.conversation.messages[lastIndex].content += chunk
                    }
                }
            }

            // 流式响应完成，如果开启自动播报，在后台播放语音（不阻塞 UI）
            if autoPlayResponse, let lastMessage = await MainActor.run(body: { conversation.messages.last }) {
                Task.detached {
                    await self.playResponse(text: lastMessage.content)
                }
            }
        } catch {
            // 在主线程更新 UI 状态
            await MainActor.run {
                errorMessage = "生成回复失败: \(error.localizedDescription)"
                isLoading = false

                // 移除空的助手消息
                if conversation.messages.last?.content.isEmpty == true {
                    conversation.messages.removeLast()
                }
            }
        }
    }

    private func playResponse(text: String) async {
        do {
            let audioData = try await ttsService.synthesizeSpeech(text: text)
            audioPlayer.play(data: audioData)
        } catch {
            print("TTS failed: \(error)")
        }
    }

    @MainActor
    func clearConversation() {
        conversation.clearMessages()
        errorMessage = nil
    }

    @MainActor
    func saveConversation() {
        // 保存对话到本地
        if let encoded = try? JSONEncoder().encode(conversation) {
            UserDefaults.standard.set(encoded, forKey: "savedConversation")
        }
    }

    @MainActor
    func loadConversation() {
        // 从本地加载对话
        if let savedData = UserDefaults.standard.data(forKey: "savedConversation"),
           let decoded = try? JSONDecoder().decode(Conversation.self, from: savedData) {
            conversation = decoded
        }
    }
}
