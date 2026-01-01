import Foundation

class VolcanoLLMService {
    static let shared = VolcanoLLMService()

    private init() {}

    private var apiKey: String {
        KeychainHelper.shared.load(key: "volcano_api_key") ?? ""
    }

    // 火山引擎豆包大模型 API - Responses API
    // 文档参考: https://www.volcengine.com/docs/6291/65568
    func chat(messages: [Message], streaming: Bool = false, enableWebSearch: Bool = false) async throws -> String {
        guard !apiKey.isEmpty else {
            print("❌ [LLM] 未配置认证信息！")
            print("💡 请按 ⌘, 打开设置，配置方舟平台的 API Key")
            throw VolcanoError.missingAPIKey
        }

        return try await chatWithAPIKey(messages: messages, streaming: streaming, enableWebSearch: enableWebSearch)
    }

    // 使用 API Key 认证（推荐）- Responses API
    private func chatWithAPIKey(messages: [Message], streaming: Bool, enableWebSearch: Bool) async throws -> String {
        print("🔑 [LLM] 使用 API Key 认证")
        print("📝 [LLM] 准备发送 \(messages.count) 条消息")

        // 检测是否有多模态内容（图片）
        let hasMultimodalContent = messages.contains { $0.hasImages }

        // 多模态使用 chat/completions API，其他使用 responses API
        if hasMultimodalContent {
            return try await chatWithChatCompletionsAPI(messages: messages)
        } else {
            return try await chatWithResponsesAPI(messages: messages, enableWebSearch: enableWebSearch)
        }
    }

    // Chat Completions API - 支持多模态
    private func chatWithChatCompletionsAPI(messages: [Message]) async throws -> String {
        print("🖼️ [LLM] 使用 Chat Completions API (多模态模式)")

        let urlString = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
        print("📡 [LLM] API URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw VolcanoError.invalidURL
        }

        // 构建消息数组
        let messagesArray = messages.map { message -> [String: Any] in
            var messageDict: [String: Any] = ["role": message.role.rawValue]

            if message.hasImages {
                // 多模态消息：使用 content 数组
                var contentArray: [[String: Any]] = []

                // 添加图片内容
                for attachment in message.imageAttachments {
                    let base64URL = ImageProcessor.toBase64DataURL(data: attachment.data, mimeType: attachment.mimeType)
                    contentArray.append([
                        "type": "image_url",
                        "image_url": ["url": base64URL]
                    ])
                }

                // 添加文本内容（如果有）
                if !message.content.isEmpty {
                    contentArray.append([
                        "type": "text",
                        "text": message.content
                    ])
                }

                messageDict["content"] = contentArray
            } else {
                // 纯文本消息
                messageDict["content"] = message.content
            }

            return messageDict
        }

        let requestBody: [String: Any] = [
            "model": VolcanoConfig.modelName,
            "messages": messagesArray
        ]

        let imageCount = messages.reduce(0) { $0 + $1.imageAttachments.count }
        print("🖼️ [LLM] 包含图片: \(imageCount) 张")
        print("📤 [LLM] 消息数量: \(messages.count)")

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        let headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]

        do {
            let response: ChatCompletionsResponse = try await NetworkManager.shared.request(
                url: url,
                method: "POST",
                headers: headers,
                body: jsonData,
                responseType: ChatCompletionsResponse.self
            )

            print("✅ [LLM] 收到响应")

            guard let firstChoice = response.choices.first,
                  let content = firstChoice.message.content else {
                print("❌ [LLM] 响应中没有内容")
                throw VolcanoError.emptyResponse
            }

            print("✅ [LLM] 成功获取回复，长度: \(content.count) 字符")

            if let usage = response.usage {
                print("📊 [LLM] Token 使用: 输入=\(usage.prompt_tokens), 输出=\(usage.completion_tokens), 总计=\(usage.total_tokens)")
            }

            return content
        } catch let error as URLError {
            print("❌ [LLM] 网络错误: \(error.localizedDescription)")
            throw VolcanoError.requestFailed("网络错误: \(error.localizedDescription)")
        } catch let error as DecodingError {
            print("❌ [LLM] 响应解析失败: \(error)")
            throw VolcanoError.requestFailed("响应格式错误")
        } catch {
            print("❌ [LLM] 错误: \(error)")
            throw error
        }
    }

    // Responses API - 支持联网搜索
    private func chatWithResponsesAPI(messages: [Message], enableWebSearch: Bool) async throws -> String {
        print("📝 [LLM] 使用 Responses API")
        if enableWebSearch {
            print("🌐 [LLM] 已启用联网搜索")
        }

        let urlString = "https://ark.cn-beijing.volces.com/api/v3/responses"
        print("📡 [LLM] API URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw VolcanoError.invalidURL
        }

        var requestBody: [String: Any] = [
            "model": VolcanoConfig.modelName
        ]

        if enableWebSearch {
            // 联网搜索模式：使用数组格式
            let inputMessages = messages.map { message in
                ["role": message.role.rawValue, "content": message.content]
            }
            requestBody["input"] = inputMessages
            requestBody["tools"] = [
                [
                    "type": "web_search",
                    "max_keyword": 2
                ]
            ]
            print("📤 [LLM] 请求模型: \(VolcanoConfig.modelName) (联网搜索模式)")
        } else {
            // 普通模式：使用字符串格式
            let input = messages.map { message in
                "\(message.role.rawValue): \(message.content)"
            }.joined(separator: "\n")
            requestBody["input"] = input
            print("📤 [LLM] 请求模型: \(VolcanoConfig.modelName) (普通模式)")
            print("📤 [LLM] 输入长度: \(input.count) 字符")
        }

        print("📤 [LLM] 消息数量: \(messages.count)")

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        let headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]

        do {
            let response: VolcanoResponsesAPIResponse = try await NetworkManager.shared.request(
                url: url,
                method: "POST",
                headers: headers,
                body: jsonData,
                responseType: VolcanoResponsesAPIResponse.self
            )

            print("✅ [LLM] 收到响应，状态: \(response.status)")

            // 从 output 中找到 type="message" 的项
            guard let messageOutput = response.output.first(where: { $0.type == "message" }) else {
                print("❌ [LLM] 响应中没有 message 类型的输出")
                throw VolcanoError.emptyResponse
            }

            // 提取文本内容
            guard let textContent = messageOutput.content?.first(where: { $0.type == "output_text" })?.text else {
                print("❌ [LLM] 无法提取文本内容")
                throw VolcanoError.emptyResponse
            }

            print("✅ [LLM] 成功获取回复，长度: \(textContent.count) 字符")

            // 打印 token 使用情况
            if let usage = response.usage {
                print("📊 [LLM] Token 使用: 输入=\(usage.input_tokens), 输出=\(usage.output_tokens), 总计=\(usage.total_tokens)")
                if let reasoning = usage.output_tokens_details?.reasoning_tokens {
                    print("📊 [LLM] 推理 Token: \(reasoning)")
                }
            }

            return textContent
        } catch let error as URLError {
            print("❌ [LLM] 网络错误: \(error.localizedDescription)")
            throw VolcanoError.requestFailed("网络错误: \(error.localizedDescription)")
        } catch let error as DecodingError {
            print("❌ [LLM] 响应解析失败: \(error)")
            throw VolcanoError.requestFailed("响应格式错误")
        } catch {
            print("❌ [LLM] 错误: \(error)")
            throw error
        }
    }


    // 流式响应版本（模拟流式输出）
    func chatStream(messages: [Message], enableWebSearch: Bool = false, onChunk: @escaping (String) -> Void) async throws {
        guard !apiKey.isEmpty else {
            throw VolcanoError.missingAPIKey
        }

        try await chatStreamWithAPIKey(messages: messages, enableWebSearch: enableWebSearch, onChunk: onChunk)
    }

    private func chatStreamWithAPIKey(messages: [Message], enableWebSearch: Bool, onChunk: @escaping (String) -> Void) async throws {
        print("🔑 [LLM Stream] 模拟流式输出")

        // 检测是否有多模态内容（图片）
        let hasMultimodalContent = messages.contains { $0.hasImages }

        // 多模态使用 chat/completions API，其他使用 responses API
        if hasMultimodalContent {
            try await chatStreamWithChatCompletionsAPI(messages: messages, onChunk: onChunk)
        } else {
            try await chatStreamWithResponsesAPI(messages: messages, enableWebSearch: enableWebSearch, onChunk: onChunk)
        }
    }

    // Chat Completions API - 流式版本（模拟）
    private func chatStreamWithChatCompletionsAPI(messages: [Message], onChunk: @escaping (String) -> Void) async throws {
        print("🖼️ [LLM Stream] 使用 Chat Completions API (多模态模式)")

        guard let url = URL(string: "https://ark.cn-beijing.volces.com/api/v3/chat/completions") else {
            throw VolcanoError.invalidURL
        }

        // 构建消息数组
        let messagesArray = messages.map { message -> [String: Any] in
            var messageDict: [String: Any] = ["role": message.role.rawValue]

            if message.hasImages {
                // 多模态消息：使用 content 数组
                var contentArray: [[String: Any]] = []

                // 添加图片内容
                for attachment in message.imageAttachments {
                    let base64URL = ImageProcessor.toBase64DataURL(data: attachment.data, mimeType: attachment.mimeType)
                    contentArray.append([
                        "type": "image_url",
                        "image_url": ["url": base64URL]
                    ])
                }

                // 添加文本内容（如果有）
                if !message.content.isEmpty {
                    contentArray.append([
                        "type": "text",
                        "text": message.content
                    ])
                }

                messageDict["content"] = contentArray
            } else {
                // 纯文本消息
                messageDict["content"] = message.content
            }

            return messageDict
        }

        let requestBody: [String: Any] = [
            "model": VolcanoConfig.modelName,
            "messages": messagesArray
        ]

        let imageCount = messages.reduce(0) { $0 + $1.imageAttachments.count }
        print("🖼️ [LLM Stream] 包含图片: \(imageCount) 张")

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        print("✅ [LLM Stream] 发送请求...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VolcanoError.invalidResponse
        }

        print("📊 [LLM Stream] HTTP 状态码: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ [LLM Stream] 错误详情: \(errorString.prefix(500))")
            }
            throw VolcanoError.invalidResponse
        }

        // 解析响应
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(ChatCompletionsResponse.self, from: data)

        print("✅ [LLM Stream] 收到完整响应")

        guard let firstChoice = apiResponse.choices.first,
              let textContent = firstChoice.message.content else {
            print("❌ [LLM Stream] 响应中没有内容")
            throw VolcanoError.emptyResponse
        }

        print("✅ [LLM Stream] 模拟流式输出，总长度: \(textContent.count) 字符")

        // 模拟流式输出：逐字符发送（每次发送多个字符以提高速度）
        let chunkSize = 3
        var index = textContent.startIndex

        while index < textContent.endIndex {
            let endIndex = textContent.index(index, offsetBy: chunkSize, limitedBy: textContent.endIndex) ?? textContent.endIndex
            let chunk = String(textContent[index..<endIndex])
            onChunk(chunk)
            index = endIndex

            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        print("✅ [LLM Stream] 模拟流式输出完成")
    }

    // Responses API - 流式版本（模拟）
    private func chatStreamWithResponsesAPI(messages: [Message], enableWebSearch: Bool, onChunk: @escaping (String) -> Void) async throws {
        print("📝 [LLM Stream] 使用 Responses API")
        if enableWebSearch {
            print("🌐 [LLM Stream] 已启用联网搜索")
        }

        guard let url = URL(string: "https://ark.cn-beijing.volces.com/api/v3/responses") else {
            throw VolcanoError.invalidURL
        }

        var requestBody: [String: Any] = [
            "model": VolcanoConfig.modelName
        ]

        if enableWebSearch {
            // 联网搜索模式：使用数组格式
            let inputMessages = messages.map { message in
                ["role": message.role.rawValue, "content": message.content]
            }
            requestBody["input"] = inputMessages
            requestBody["tools"] = [
                [
                    "type": "web_search",
                    "max_keyword": 2
                ]
            ]
            print("📤 [LLM Stream] 请求模型: \(VolcanoConfig.modelName) (联网搜索模式)")
        } else {
            // 普通模式：使用字符串格式
            let input = messages.map { message in
                "\(message.role.rawValue): \(message.content)"
            }.joined(separator: "\n")
            requestBody["input"] = input
        }

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        print("✅ [LLM Stream] 发送请求...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VolcanoError.invalidResponse
        }

        print("📊 [LLM Stream] HTTP 状态码: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ [LLM Stream] 错误详情: \(errorString.prefix(500))")
            }
            throw VolcanoError.invalidResponse
        }

        // 解析响应
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(VolcanoResponsesAPIResponse.self, from: data)

        print("✅ [LLM Stream] 收到完整响应，状态: \(apiResponse.status)")

        // 从 output 中找到 type="message" 的项
        guard let messageOutput = apiResponse.output.first(where: { $0.type == "message" }) else {
            print("❌ [LLM Stream] 响应中没有 message 类型的输出")
            throw VolcanoError.emptyResponse
        }

        // 提取文本内容
        guard let textContent = messageOutput.content?.first(where: { $0.type == "output_text" })?.text else {
            print("❌ [LLM Stream] 无法提取文本内容")
            throw VolcanoError.emptyResponse
        }

        print("✅ [LLM Stream] 模拟流式输出，总长度: \(textContent.count) 字符")

        // 模拟流式输出：逐字符发送（每次发送多个字符以提高速度）
        let chunkSize = 3  // 每次发送3个字符
        var index = textContent.startIndex

        while index < textContent.endIndex {
            let endIndex = textContent.index(index, offsetBy: chunkSize, limitedBy: textContent.endIndex) ?? textContent.endIndex
            let chunk = String(textContent[index..<endIndex])
            onChunk(chunk)
            index = endIndex

            // 短暂延迟以模拟流式效果（可选）
            try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        }

        print("✅ [LLM Stream] 模拟流式输出完成")
    }

}

// MARK: - Response Models for Chat Completions API

struct ChatCompletionsResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?

    struct Choice: Codable {
        let index: Int
        let message: MessageContent
        let finish_reason: String?

        struct MessageContent: Codable {
            let role: String
            let content: String?
        }
    }

    struct Usage: Codable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }
}

// MARK: - Response Models for Responses API

struct VolcanoResponsesAPIResponse: Codable {
    let id: String
    let model: String
    let status: String
    let output: [ResponseOutput]
    let usage: Usage?

    struct ResponseOutput: Codable {
        let id: String?
        let type: String
        let role: String?
        let content: [OutputContent]?
        let status: String?
        let summary: [SummaryContent]?

        struct OutputContent: Codable {
            let type: String
            let text: String?
        }

        struct SummaryContent: Codable {
            let type: String
            let text: String?
        }
    }

    struct Usage: Codable {
        let input_tokens: Int
        let output_tokens: Int
        let total_tokens: Int
        let input_tokens_details: InputTokensDetails?
        let output_tokens_details: OutputTokensDetails?

        struct InputTokensDetails: Codable {
            let cached_tokens: Int
        }

        struct OutputTokensDetails: Codable {
            let reasoning_tokens: Int?
        }
    }
}

enum VolcanoError: Error, LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case emptyResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未配置 API Key，请在方舟平台创建应用并获取 API Key"
        case .invalidURL:
            return "API 地址无效"
        case .invalidResponse:
            return "服务器响应无效，请检查 API Key 是否正确"
        case .emptyResponse:
            return "服务器返回空响应"
        case .requestFailed(let message):
            return message
        }
    }
}
