import SwiftUI

struct APITestView: View {
    @State private var apiKey = ""
    @State private var result = ""
    @State private var isTesting = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("API 配置测试")
                .font(.title)
                .bold()

            SecureField("输入 API Key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 400)

            Button(action: testAPI) {
                HStack {
                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isTesting ? "测试中..." : "测试 API 连接")
                }
                .frame(width: 200)
                .padding()
                .background(apiKey.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isTesting || apiKey.isEmpty)

            if !result.isEmpty {
                ScrollView {
                    Text(result)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(height: 300)
            }

            HStack {
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            Spacer()
        }
        .padding()
        .frame(width: 600, height: 500)
    }

    private func testAPI() {
        isTesting = true
        result = "开始测试 API 连接...\n\n"

        Task {
            do {
                let url = URL(string: "https://ark.cn-beijing.volces.com/api/v3/chat/completions")!

                result += "📡 测试 URL: \(url.absoluteString)\n"
                result += "🔑 API Key: \(apiKey.prefix(10))***\n\n"

                let requestBody: [String: Any] = [
                    "model": "doubao-pro-4k",
                    "messages": [
                        ["role": "user", "content": "你好"]
                    ]
                ]

                let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = jsonData
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

                result += "📤 发送请求...\n\n"

                let (data, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    result += "📊 HTTP 状态码: \(httpResponse.statusCode)\n\n"

                    if (200...299).contains(httpResponse.statusCode) {
                        result += "✅ 请求成功！API Key 有效\n\n"
                    } else {
                        result += "❌ 请求失败！\n\n"
                    }
                }

                if let responseString = String(data: data, encoding: .utf8) {
                    result += "📥 响应内容:\n\(responseString)\n"
                }

                isTesting = false
            } catch {
                result += "\n❌ 错误: \(error.localizedDescription)\n"
                isTesting = false
            }
        }
    }
}

#Preview {
    APITestView()
}
