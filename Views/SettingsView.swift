import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 方舟平台配置
                SettingsSection(
                    title: "方舟平台配置",
                    icon: "cloud.fill",
                    iconColor: .blue
                ) {
                    VStack(spacing: 16) {
                        SettingsTextField(
                            label: "API Key",
                            text: $viewModel.apiKey,
                            isSecure: true,
                            placeholder: "输入您的 API Key"
                        )

                        SettingsTextField(
                            label: "模型/Endpoint ID",
                            text: $viewModel.modelName,
                            placeholder: "ep-xxxxxxxx"
                        )
                    }
                }

                // 语音服务配置
                SettingsSection(
                    title: "语音服务配置",
                    icon: "mic.fill",
                    iconColor: .purple
                ) {
                    VStack(spacing: 16) {
                        SettingsTextField(
                            label: "App ID",
                            text: $viewModel.speechAppId,
                            placeholder: "输入您的 App ID"
                        )

                        SettingsTextField(
                            label: "Access Token",
                            text: $viewModel.speechAccessToken,
                            isSecure: true,
                            placeholder: "输入您的 Access Token"
                        )
                    }
                }

                // 系统提示词
                SettingsSection(
                    title: "系统提示词",
                    icon: "text.bubble.fill",
                    iconColor: .orange
                ) {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("System Prompt")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)

                            TextEditor(text: $viewModel.systemPrompt)
                                .font(.system(size: 13))
                                .frame(height: 100)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                )
                        }
                    }
                }

                // 快捷键与功能
                SettingsSection(
                    title: "快捷键与功能",
                    icon: "keyboard.fill",
                    iconColor: .pink
                ) {
                    VStack(spacing: 20) {
                        // 录音快捷键
                        VStack(alignment: .leading, spacing: 10) {
                            Text("录音快捷键")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)

                            HotkeyRecorderView(
                                keyCode: $viewModel.recordingHotkeyCode,
                                modifiers: $viewModel.recordingHotkeyModifiers
                            )

                            Text("设置全局快捷键以启动录音（默认：⌥ Option）")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        // 截图快捷键
                        VStack(alignment: .leading, spacing: 10) {
                            Text("截图快捷键")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)

                            HotkeyRecorderView(
                                keyCode: $viewModel.screenshotHotkeyCode,
                                modifiers: $viewModel.screenshotHotkeyModifiers
                            )

                            Text("设置全局快捷键以截图（默认：⌃A）")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        // 联网搜索
                        SettingsToggle(
                            label: "启用联网搜索",
                            description: "开启后，AI 可以搜索实时信息回答问题",
                            isOn: $viewModel.enableWebSearch
                        )

                        Divider()

                        // 自动语音播报
                        SettingsToggle(
                            label: "自动语音播报",
                            description: "开启后，AI 回复会自动转换为语音播放",
                            isOn: $viewModel.autoPlayResponse
                        )
                    }
                }

                // 保存按钮
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.saveSettings()
                    }) {
                        Text("保存设置")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 120, height: 32)
                            .background(
                                viewModel.apiKey.isEmpty || viewModel.modelName.isEmpty
                                    ? Color.gray
                                    : Color.accentColor
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.apiKey.isEmpty || viewModel.modelName.isEmpty)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .frame(width: 600, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("设置已保存", isPresented: $viewModel.showingSaveAlert) {
            Button("好的", role: .cancel) {}
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content

    init(
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Settings TextField

struct SettingsTextField: View {
    let label: String
    @Binding var text: String
    var isSecure: Bool = false
    var placeholder: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Settings Toggle

struct SettingsToggle: View {
    let label: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

// MARK: - Help Box

struct HelpBox: View {
    let text: String
    let details: [String]
    let linkText: String
    let linkURL: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                ForEach(details, id: \.self) { detail in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Link(destination: URL(string: linkURL)!) {
                HStack(spacing: 4) {
                    Text(linkText)
                        .font(.system(size: 12, weight: .medium))

                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.accentColor)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
        )
    }
}

#Preview {
    SettingsView()
}
