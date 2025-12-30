import Foundation

class VolcanoASRService {
    static let shared = VolcanoASRService()

    private init() {}

    private var appId: String {
        KeychainHelper.shared.load(key: "volcano_speech_appid") ?? ""
    }

    private var accessToken: String {
        KeychainHelper.shared.load(key: "volcano_speech_token") ?? ""
    }

    // 火山引擎语音识别 API（新版 BigModel Flash API）
    // 文档参考: https://www.volcengine.com/docs/6561/1221033
    func recognizeSpeech(audioURL: URL) async throws -> String {
        print("🎤 [ASR] 开始语音识别")

        guard !appId.isEmpty else {
            print("❌ [ASR] App ID 未配置")
            throw VolcanoError.missingAPIKey
        }

        guard !accessToken.isEmpty else {
            print("❌ [ASR] Access Token 未配置")
            throw VolcanoError.missingAPIKey
        }

        guard let url = URL(string: "https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash") else {
            throw VolcanoError.invalidURL
        }

        // 读取音频文件并转换为 Base64
        let audioData = try Data(contentsOf: audioURL)
        let base64Audio = audioData.base64EncodedString()

        print("📊 [ASR] 音频文件大小: \(audioData.count) bytes")

        // 构造请求体
        let requestBody: [String: Any] = [
            "user": [
                "uid": appId
            ],
            "audio": [
                "data": base64Audio
            ],
            "request": [
                "model_name": "bigmodel"
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        // 构造请求头
        let headers = [
            "Content-Type": "application/json",
            "X-Api-App-Key": appId,
            "X-Api-Access-Key": accessToken,
            "X-Api-Resource-Id": "volc.bigasr.auc_turbo",
            "X-Api-Request-Id": UUID().uuidString,
            "X-Api-Sequence": "-1"
        ]

        print("📤 [ASR] 发送识别请求...")

        // 先获取原始响应数据用于调试
        let responseData = try await NetworkManager.shared.requestData(
            url: url,
            method: "POST",
            headers: headers,
            body: jsonData
        )

        // 打印原始响应
        if let responseString = String(data: responseData, encoding: .utf8) {
            print("📄 [ASR] 原始响应: \(responseString.prefix(500))")
        }

        // 解析响应
        let decoder = JSONDecoder()
        let response = try decoder.decode(VolcanoASRResponse.self, from: responseData)

        print("📊 [ASR] 解析结果: result=\(String(describing: response.result))")

        guard let text = response.result?.text, !text.isEmpty else {
            print("❌ [ASR] 识别结果为空")
            throw VolcanoError.emptyResponse
        }

        print("✅ [ASR] 识别成功: \(text)")
        return text
    }
}

// MARK: - Response Models

struct VolcanoASRResponse: Codable {
    let result: ASRResult?

    struct ASRResult: Codable {
        let text: String
    }
}
