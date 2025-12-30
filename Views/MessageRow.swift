import SwiftUI

struct MessageRow: View {
    let message: Message
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                // 使用 Markdown 渲染（仅对 assistant 消息）
                if message.role == .assistant {
                    MarkdownText(content: message.content, textColor: messageForeground)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(messageBackground)
                        .clipShape(MessageBubble(isFromCurrentUser: message.role == .user))
                } else {
                    Text(message.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(messageBackground)
                        .foregroundColor(messageForeground)
                        .clipShape(MessageBubble(isFromCurrentUser: message.role == .user))
                        .textSelection(.enabled)
                }

                Text(formatTime(message.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: 500, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    private var messageBackground: Color {
        if message.role == .user {
            return Color.blue
        } else {
            return colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.90)
        }
    }

    private var messageForeground: Color {
        if message.role == .user {
            return .white
        } else {
            return .primary
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// iMessage 风格的气泡形状
struct MessageBubble: Shape {
    let isFromCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6

        var path = Path()

        if isFromCurrentUser {
            // 右侧气泡（用户消息）
            path.move(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: radius),
                control: CGPoint(x: rect.width, y: 0)
            )
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.width - radius, y: rect.height),
                control: CGPoint(x: rect.width, y: rect.height)
            )
            // 右下角小尾巴
            path.addLine(to: CGPoint(x: rect.width - radius - tailSize, y: rect.height))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: rect.height + tailSize),
                control: CGPoint(x: rect.width - 2, y: rect.height + tailSize)
            )
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: radius, y: rect.height))
            path.addQuadCurve(
                to: CGPoint(x: 0, y: rect.height - radius),
                control: CGPoint(x: 0, y: rect.height)
            )
            path.addLine(to: CGPoint(x: 0, y: radius))
            path.addQuadCurve(
                to: CGPoint(x: radius, y: 0),
                control: CGPoint(x: 0, y: 0)
            )
        } else {
            // 左侧气泡（助手消息）
            path.move(to: CGPoint(x: radius, y: 0))
            path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: radius),
                control: CGPoint(x: rect.width, y: 0)
            )
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.width - radius, y: rect.height),
                control: CGPoint(x: rect.width, y: rect.height)
            )
            path.addLine(to: CGPoint(x: radius, y: rect.height))
            path.addQuadCurve(
                to: CGPoint(x: 0, y: rect.height - radius),
                control: CGPoint(x: 0, y: rect.height)
            )
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            // 左下角小尾巴
            path.addQuadCurve(
                to: CGPoint(x: -tailSize, y: rect.height + tailSize),
                control: CGPoint(x: 2, y: rect.height + tailSize)
            )
            path.addLine(to: CGPoint(x: tailSize, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: radius))
            path.addQuadCurve(
                to: CGPoint(x: radius, y: 0),
                control: CGPoint(x: 0, y: 0)
            )
        }

        return path
    }
}
