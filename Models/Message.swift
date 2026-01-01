import Foundation

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let role: Role
    var contentParts: [MessageContentType]  // 多模态内容
    let timestamp: Date

    enum Role: String, Codable {
        case system
        case user
        case assistant
    }

    // MARK: - 初始化

    init(id: UUID = UUID(), role: Role, contentParts: [MessageContentType], timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.contentParts = contentParts
        self.timestamp = timestamp
    }

    // 便利初始化方法：纯文本消息（向后兼容）
    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.contentParts = [.text(content)]
        self.timestamp = timestamp
    }

    // 便利初始化方法：文本 + 图片
    init(id: UUID = UUID(), role: Role, text: String, images: [ImageAttachment], timestamp: Date = Date()) {
        self.id = id
        self.role = role
        var parts: [MessageContentType] = []
        if !text.isEmpty {
            parts.append(.text(text))
        }
        parts.append(contentsOf: images.map { .image($0) })
        self.contentParts = parts
        self.timestamp = timestamp
    }

    // MARK: - 便利属性

    /// 文本内容（向后兼容）
    var content: String {
        get {
            contentParts.textContent
        }
        set {
            contentParts = [.text(newValue)]
        }
    }

    /// 图片附件
    var imageAttachments: [ImageAttachment] {
        contentParts.imageAttachments
    }

    /// 是否包含图片
    var hasImages: Bool {
        contentParts.hasImages
    }

    /// 是否为纯文本消息
    var isTextOnly: Bool {
        contentParts.count == 1 && !hasImages
    }
}
