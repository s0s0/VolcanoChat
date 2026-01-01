import SwiftUI

/// 图片附件预览卡片（用于输入框中显示待发送的图片）
struct ImageAttachmentView: View {
    let attachment: ImageAttachment
    let onRemove: () -> Void
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false

    var body: some View {
        // 图片缩略图
        ZStack(alignment: .center) {
            if let thumbnail = attachment.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }

            // 删除按钮（鼠标悬停时显示在中央）
            if isHovered {
                Button(action: onRemove) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 32, height: 32)

                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 80, height: 80)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

/// 消息中的图片显示（用于消息行中显示）
struct MessageImageView: View {
    let attachment: ImageAttachment
    @State private var isShowingFullImage = false

    var body: some View {
        Group {
            if let image = attachment.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 300, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .onTapGesture {
                        isShowingFullImage = true
                    }
                    .sheet(isPresented: $isShowingFullImage) {
                        FullImageView(image: image)
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("无法加载图片")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
}

/// 全屏图片查看器
struct FullImageView: View {
    let image: NSImage
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

            // 关闭按钮
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()
            }
        }
        .onTapGesture {
            dismiss()
        }
    }
}

/// 图片网格布局（用于显示多张图片）
struct ImageGridView: View {
    let attachments: [ImageAttachment]

    var body: some View {
        let columns = gridColumns(for: attachments.count)

        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(attachments, id: \.id) { attachment in
                MessageImageView(attachment: attachment)
            }
        }
    }

    private func gridColumns(for count: Int) -> [GridItem] {
        switch count {
        case 1:
            return [GridItem(.flexible())]
        case 2:
            return [GridItem(.flexible()), GridItem(.flexible())]
        case 3:
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        case 4:
            return [GridItem(.flexible()), GridItem(.flexible())]
        default:  // 5 张
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
    }
}

#Preview {
    VStack {
        if let sampleImage = NSImage(systemSymbolName: "photo", accessibilityDescription: nil) {
            let sampleData = sampleImage.tiffRepresentation ?? Data()
            let attachment = ImageAttachment(
                data: sampleData,
                mimeType: "image/png",
                width: 100,
                height: 100
            )

            ImageAttachmentView(attachment: attachment) {
                print("Remove tapped")
            }
        }
    }
    .padding()
}
