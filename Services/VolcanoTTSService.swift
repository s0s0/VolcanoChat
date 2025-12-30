import Foundation

// MARK: - TTS Response Models
struct VolcanoTTSResponse: Codable {
    let reqid: String
    let code: Int
    let operation: String
    let message: String
    let sequence: Int
    let data: String  // Base64 编码的音频数据
}

class VolcanoTTSService {
    static let shared = VolcanoTTSService()

    private init() {}

    private var appId: String {
        KeychainHelper.shared.load(key: "volcano_speech_appid") ?? ""
    }

    private var accessToken: String {
        KeychainHelper.shared.load(key: "volcano_speech_token") ?? ""
    }

    // 火山引擎语音合成 API
    // 文档参考: https://www.volcengine.com/docs/6561/79816
    func synthesizeSpeech(text: String, voice: String = "zh_female_vv_uranus_bigtts") async throws -> Data {
        print("🔊 [TTS] 开始语音合成")
        print("📝 [TTS] 文本长度: \(text.count) 字符")

        guard !appId.isEmpty else {
            print("❌ [TTS] App ID 未配置")
            print("💡 [TTS] 请在设置中配置 TTS App ID")
            throw VolcanoError.missingAPIKey
        }

        guard !accessToken.isEmpty else {
            print("❌ [TTS] Access Token 未配置")
            print("💡 [TTS] 请在设置中配置 TTS Access Token")
            throw VolcanoError.missingAPIKey
        }

        // 火山引擎 TTS API endpoint
        let urlString = "https://openspeech.bytedance.com/api/v1/tts"
        print("📡 [TTS] API URL: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw VolcanoError.invalidURL
        }

        let requestBody: [String: Any] = [
            "app": [
                "appid": appId,
                "token": accessToken,  // 使用专门的 TTS Access Token
                "cluster": "volcano_tts"
            ],
            "user": [
                "uid": "user_001"
            ],
            "audio": [
                "voice_type": voice,
                "encoding": "mp3",
                "speed_ratio": 1.0,
                "volume_ratio": 1.0,
                "pitch_ratio": 1.0
            ],
            "request": [
                "reqid": UUID().uuidString,
                "text": text,
                "text_type": "plain",
                "operation": "query"
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        // 打印请求体用于调试
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📦 [TTS] 请求体: \(jsonString)")
        }

        // 根据火山引擎官方文档，TTS API 的认证信息主要在请求体中
        // Authorization 头可能不需要或格式不同
        let headers = [
            "Content-Type": "application/json"
        ]

        print("🔑 [TTS] App ID: \(appId)")
        print("🔑 [TTS] Access Token 长度: \(accessToken.count) 字符")
        print("🔑 [TTS] Token 前缀: \(accessToken.prefix(20))...")
        print("📤 [TTS] 发送请求...")

        do {
            let responseData = try await NetworkManager.shared.requestData(
                url: url,
                method: "POST",
                headers: headers,
                body: jsonData
            )

            print("✅ [TTS] 成功获取响应，大小: \(responseData.count) bytes")

            // 解析 JSON 响应
            let decoder = JSONDecoder()
            let response = try decoder.decode(VolcanoTTSResponse.self, from: responseData)

            print("📊 [TTS] 响应码: \(response.code), 消息: \(response.message)")

            guard response.code == 3000 else {
                print("❌ [TTS] API 返回错误: code=\(response.code), message=\(response.message)")
                throw VolcanoError.requestFailed(response.message)
            }

            // Base64 解码音频数据
            guard let audioData = Data(base64Encoded: response.data) else {
                print("❌ [TTS] Base64 解码失败")
                throw VolcanoError.requestFailed("无法解码音频数据")
            }

            print("✅ [TTS] 成功解码音频数据，大小: \(audioData.count) bytes")

            // 检查音频文件头（MP3 通常以 FF FB 或 FF F3 或 ID3 开头）
            let prefix = audioData.prefix(4)
            print("📊 [TTS] 音频数据前4字节: \(prefix.map { String(format: "%02X", $0) }.joined(separator: " "))")

            return audioData
        } catch let error as DecodingError {
            print("❌ [TTS] JSON 解析失败: \(error)")
            throw VolcanoError.requestFailed("响应格式错误")
        } catch {
            print("❌ [TTS] 请求失败: \(error)")
            throw error
        }
    }
}
