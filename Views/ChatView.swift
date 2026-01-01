import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @ObservedObject private var conversationManager = ConversationManager.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // iMessage 风格的背景
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 工具栏
                HStack {
                    Text("Volcano Chatbot")
                        .font(.system(size: 16, weight: .semibold))

                    Spacer()

                    Button(action: {
                        viewModel.clearConversation()
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("清空对话")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Color(nsColor: colorScheme == .dark ? NSColor.windowBackgroundColor : NSColor.controlBackgroundColor)
                        .opacity(0.95)
                )
                .overlay(
                    Divider()
                        .offset(y: 1),
                    alignment: .bottom
                )

                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            // 只显示 user 和 assistant 消息，不显示 system 消息
                            ForEach(conversationManager.conversation.messages.filter { $0.role != .system }) { message in
                                MessageRow(message: message)
                                    .id(message.id)
                            }

                            if conversationManager.isLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .padding(.leading, 16)
                                    Text("正在思考...")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: conversationManager.conversation.messages.count) { _, _ in
                        if let lastMessage = conversationManager.conversation.messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // 错误提示
                if let error = conversationManager.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 13))
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.15))
                }

                // 输入栏
                InputBar(
                    text: $viewModel.inputText,
                    imageAttachments: $viewModel.imageAttachments,
                    onSend: {
                        viewModel.sendTextMessage()
                    },
                    onVoicePress: {
                        viewModel.startRecording()
                    },
                    onVoiceRelease: {
                        viewModel.stopRecording()
                    },
                    isRecording: $viewModel.isRecording
                )
            }
        }
    }
}

#Preview {
    ChatView()
        .frame(width: 800, height: 600)
}
