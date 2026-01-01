import SwiftUI
import UniformTypeIdentifiers

struct InputBar: View {
    @Binding var text: String
    @Binding var imageAttachments: [ImageAttachment]  // 图片附件
    let onSend: () -> Void
    let onVoicePress: () -> Void
    let onVoiceRelease: () -> Void
    @Binding var isRecording: Bool
    @Environment(\.colorScheme) var colorScheme

    @State private var showingImagePicker = false
    @State private var showingPasteAlert = false
    @FocusState private var isTextFieldFocused: Bool

    private let maxImages = 5

    var body: some View {
        VStack(spacing: 8) {
            // 图片预览区域
            if !imageAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(imageAttachments, id: \.id) { attachment in
                            ImageAttachmentView(attachment: attachment) {
                                removeAttachment(attachment)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 100)
            }

            // 文本输入框
            HStack(spacing: 8) {
                // 上传图片按钮
                Button {
                    selectImages()
                } label: {
                    Image(systemName: "photo.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(imageAttachments.count >= maxImages ? .gray : .blue)
                }
                .buttonStyle(.plain)
                .disabled(imageAttachments.count >= maxImages)
                .help("上传图片（最多\(maxImages)张）")

                TextField("iMessage", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(1...5)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        onSend()
                    }

                // 发送按钮（集成在输入框内）
                if !text.isEmpty || !imageAttachments.isEmpty {
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
            .overlay(
                // 隐藏的粘贴按钮，用于响应 ⌘V 快捷键
                Button(action: pasteFromClipboard) {
                    EmptyView()
                }
                .keyboardShortcut("v", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            )
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(
            Color(nsColor: colorScheme == .dark ? NSColor.windowBackgroundColor : NSColor.controlBackgroundColor)
                .opacity(0.95)
        )
        .overlay(
            Divider(),
            alignment: .top
        )
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.png, .jpeg, .gif, .webP],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result: result)
        }
        .alert("已添加 \(imageAttachments.count)/\(maxImages) 张图片", isPresented: $showingPasteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if imageAttachments.count >= maxImages {
                Text("已达到最大数量限制")
            }
        }
    }

    // MARK: - Private Methods

    private func selectImages() {
        showingImagePicker = true
    }

    // 从剪贴板粘贴图片
    private func pasteFromClipboard() {
        print("📋 [InputBar] 尝试从剪贴板粘贴图片")

        guard imageAttachments.count < maxImages else {
            showingPasteAlert = true
            return
        }

        let attachments = ImageProcessor.loadAttachmentsFromPasteboard()

        if attachments.isEmpty {
            print("⚠️ [InputBar] 剪贴板中没有图片")
            return
        }

        for attachment in attachments {
            guard imageAttachments.count < maxImages else {
                showingPasteAlert = true
                break
            }
            imageAttachments.append(attachment)
        }

        print("✅ [InputBar] 从剪贴板添加了 \(attachments.count) 张图片")
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard imageAttachments.count < maxImages else {
                    showingPasteAlert = true
                    break
                }

                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }

                    if let attachment = ImageProcessor.loadAttachment(from: url) {
                        imageAttachments.append(attachment)
                    }
                }
            }
        case .failure(let error):
            print("❌ [InputBar] 文件选择失败: \(error)")
        }
    }

    private func removeAttachment(_ attachment: ImageAttachment) {
        imageAttachments.removeAll { $0.id == attachment.id }
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @State var images: [ImageAttachment] = []
    @Previewable @State var isRecording = false

    InputBar(
        text: $text,
        imageAttachments: $images,
        onSend: { print("Send") },
        onVoicePress: { isRecording = true },
        onVoiceRelease: { isRecording = false },
        isRecording: $isRecording
    )
}
