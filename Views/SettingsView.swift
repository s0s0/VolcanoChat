import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            Section {
                SecureField("API Key", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)

                TextField("模型/Endpoint ID", text: $viewModel.modelName)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 4) {
                    Text("在方舟平台获取 API Key 和 Endpoint ID")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("路径：方舟平台 → 推理接入 → 我的应用")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("Endpoint ID 通常以 ep- 开头")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }

                Link("打开方舟平台", destination: URL(string: "https://console.volcengine.com/ark")!)
                    .font(.caption)
            } header: {
                Text("方舟平台配置 (推荐)")
            }

            Section {
                TextField("语音服务 App ID", text: $viewModel.speechAppId)
                    .textFieldStyle(.roundedBorder)

                SecureField("语音服务 Access Token", text: $viewModel.speechAccessToken)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 4) {
                    Text("用于语音识别（ASR）和语音合成（TTS）")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("路径：火山引擎控制台 → 语音技术 → 项目管理")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("注意：语音服务的认证独立于方舟平台")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                Link("打开语音技术控制台", destination: URL(string: "https://console.volcengine.com/speech")!)
                    .font(.caption)
            } header: {
                Text("语音服务配置")
            }

            Section {
                Toggle("自动语音播报", isOn: $viewModel.autoPlayResponse)

                Text("开启后，AI 回复会自动转换为语音播放")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("语音设置")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Prompt")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextEditor(text: $viewModel.systemPrompt)
                        .frame(height: 80)
                        .font(.system(size: 12))
                        .border(Color.gray.opacity(0.3), width: 1)

                    Text("自定义 AI 的角色和行为，例如：\"你是一个专业的编程助手\"")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("系统提示词")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("录音快捷键")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HotkeyRecorderView(
                        keyCode: $viewModel.recordingHotkeyCode,
                        modifiers: $viewModel.recordingHotkeyModifiers
                    )

                    Text("设置全局快捷键以启动录音（默认：⌥ Option）")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("截图快捷键")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HotkeyRecorderView(
                        keyCode: $viewModel.screenshotHotkeyCode,
                        modifiers: $viewModel.screenshotHotkeyModifiers
                    )

                    Text("设置全局快捷键以截图（默认：⌘⇧A，截图仅保存到剪贴板）")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)

                Toggle("启用联网搜索", isOn: $viewModel.enableWebSearch)

                Text("开启后，AI 可以搜索实时信息回答问题")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("功能设置")
            }

            Section {
                Button("保存设置") {
                    viewModel.saveSettings()
                }
                .disabled(viewModel.apiKey.isEmpty || viewModel.modelName.isEmpty)
            }
        }
        .formStyle(.grouped)
        .frame(width: 550, height: 700)
        .alert("设置已保存", isPresented: $viewModel.showingSaveAlert) {
            Button("OK", role: .cancel) {}
        }
    }
}

#Preview {
    SettingsView()
}
