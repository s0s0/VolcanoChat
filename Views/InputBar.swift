import SwiftUI

struct InputBar: View {
    @Binding var text: String
    let onSend: () -> Void
    let onVoicePress: () -> Void
    let onVoiceRelease: () -> Void
    @Binding var isRecording: Bool
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            // 语音按钮
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red.opacity(0.15) : Color.clear)
                        .frame(width: 32, height: 32)

                    Image(systemName: isRecording ? "mic.fill" : "mic.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(isRecording ? .red : (colorScheme == .dark ? .white : Color(white: 0.5)))
                }
            }
            .buttonStyle(.plain)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isRecording {
                            onVoicePress()
                        }
                    }
                    .onEnded { _ in
                        if isRecording {
                            onVoiceRelease()
                        }
                    }
            )
            .help("按住录音")

            // 文本输入框
            HStack {
                TextField("iMessage", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...5)
                    .onSubmit {
                        onSend()
                    }

                // 发送按钮（集成在输入框内）
                if !text.isEmpty {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color(nsColor: colorScheme == .dark ? NSColor.windowBackgroundColor : NSColor.controlBackgroundColor)
                .opacity(0.95)
        )
        .overlay(
            Divider(),
            alignment: .top
        )
    }
}
