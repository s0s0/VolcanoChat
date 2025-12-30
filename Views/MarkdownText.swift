import SwiftUI

/// 支持 Markdown 渲染的文本视图
struct MarkdownText: View {
    let content: String
    let textColor: Color

    var body: some View {
        if #available(macOS 12.0, *) {
            // macOS 12+ 使用原生 Markdown 支持
            Text(parseMarkdown(content))
                .textSelection(.enabled)
        } else {
            // macOS 11 及以下使用纯文本
            Text(content)
                .textSelection(.enabled)
        }
    }

    @available(macOS 12.0, *)
    private func parseMarkdown(_ text: String) -> AttributedString {
        do {
            // 尝试解析 Markdown
            var attributedString = try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))

            // 设置基础文本颜色
            attributedString.foregroundColor = textColor

            return attributedString
        } catch {
            // 如果解析失败，返回纯文本
            print("⚠️ [Markdown] 解析失败: \(error)")
            var fallback = AttributedString(text)
            fallback.foregroundColor = textColor
            return fallback
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        MarkdownText(
            content: "这是一段包含 **粗体** 和 *斜体* 的文本",
            textColor: .primary
        )

        MarkdownText(
            content: """
            # 标题

            这是一个列表：
            - 项目 1
            - 项目 2
            - 项目 3

            代码示例：`print("Hello")`
            """,
            textColor: .primary
        )
    }
    .padding()
}
