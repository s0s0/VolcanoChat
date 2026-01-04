import Foundation

class ConversationManager: ObservableObject {
    static let shared = ConversationManager()

    // 默认 system prompt
    static let defaultSystemPrompt = "你会言简意赅的输出内容，不要说没用的废话，只输出必要信息"

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

    // 发送多模态消息（文本 + 图片）
    func sendMessage(text: String, images: [ImageAttachment]) async {
        let userMessage = Message(role: .user, text: text, images: images)
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

        // 获取用户自定义的 system prompt，如果为空则使用默认 prompt
        let customSystemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? ""
        let systemPrompt = customSystemPrompt.isEmpty ? ConversationManager.defaultSystemPrompt : customSystemPrompt

        // 在消息列表开头插入 system 消息（不保存到 conversation 中，只发送给 LLM）
        let systemMessage = Message(role: .system, content: systemPrompt)
        messagesToSend.insert(systemMessage, at: 0)

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
            // 清理 markdown 格式后再合成语音
            let cleanedText = cleanMarkdown(text)
            let audioData = try await ttsService.synthesizeSpeech(text: cleanedText)
            audioPlayer.play(data: audioData)
        } catch {
            print("TTS failed: \(error)")
        }
    }

    /// 清理 markdown 格式符号，保留纯文本内容
    private func cleanMarkdown(_ text: String) -> String {
        var result = text

        // 移除代码块 ```...```
        result = result.replacingOccurrences(of: "```[^`]*```", with: "", options: .regularExpression)

        // 移除行内代码 `...`
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)

        // 移除粗体 **...** 和 __...__
        result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "__([^_]+)__", with: "$1", options: .regularExpression)

        // 移除斜体 *...* 和 _..._
        result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)

        // 移除删除线 ~~...~~
        result = result.replacingOccurrences(of: "~~([^~]+)~~", with: "$1", options: .regularExpression)

        // 移除链接 [text](url)，保留文本
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)

        // 移除图片 ![alt](url)
        result = result.replacingOccurrences(of: "!\\[([^\\]]*)\\]\\([^)]+\\)", with: "", options: .regularExpression)

        // 移除标题符号 #
        result = result.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n#{1,6}\\s+", with: "\n", options: .regularExpression)

        // 移除引用符号 >
        result = result.replacingOccurrences(of: "^>\\s+", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n>\\s+", with: "\n", options: .regularExpression)

        // 移除列表符号 - 和 *
        result = result.replacingOccurrences(of: "^[-*+]\\s+", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n[-*+]\\s+", with: "\n", options: .regularExpression)

        // 移除有序列表数字
        result = result.replacingOccurrences(of: "^\\d+\\.\\s+", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n\\d+\\.\\s+", with: "\n", options: .regularExpression)

        // 移除水平分割线
        result = result.replacingOccurrences(of: "^[-*_]{3,}$", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n[-*_]{3,}\n", with: "\n", options: .regularExpression)

        // 移除多余的空白行
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        // 去除首尾空白
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
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
