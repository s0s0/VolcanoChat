import Foundation
import AppKit

/// 消息内容类型（支持多模态）
enum MessageContentType: Codable, Equatable {
    case text(String)
    case image(ImageAttachment)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image":
            let image = try container.decode(ImageAttachment.self, forKey: .image)
            self = .image(image)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown content type")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let image):
            try container.encode("image", forKey: .type)
            try container.encode(image, forKey: .image)
        }
    }
}

/// 图片附件
struct ImageAttachment: Codable, Equatable {
    let id: UUID
    let data: Data
    let mimeType: String  // image/png, image/jpeg, etc.
    let width: Int?
    let height: Int?

    // 缩略图不参与编码（运行时生成）
    var thumbnail: NSImage? {
        guard let image = NSImage(data: data) else { return nil }
        return ImageProcessor.generateThumbnail(from: image, maxSize: CGSize(width: 200, height: 200))
    }

    // 原始图片
    var image: NSImage? {
        return NSImage(data: data)
    }

    // 文件大小（格式化）
    var formattedSize: String {
        let bytes = Double(data.count)
        if bytes < 1024 {
            return String(format: "%.0f B", bytes)
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        }
    }

    // 文件扩展名
    var fileExtension: String {
        switch mimeType {
        case "image/png": return "PNG"
        case "image/jpeg", "image/jpg": return "JPG"
        case "image/gif": return "GIF"
        case "image/webp": return "WebP"
        default: return "Image"
        }
    }

    init(id: UUID = UUID(), data: Data, mimeType: String, width: Int? = nil, height: Int? = nil) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
        self.width = width
        self.height = height
    }
}

// MARK: - 便利方法

extension Array where Element == MessageContentType {
    /// 提取所有文本内容
    var textContent: String {
        compactMap { content in
            if case .text(let text) = content {
                return text
            }
            return nil
        }.joined(separator: "\n")
    }

    /// 提取所有图片附件
    var imageAttachments: [ImageAttachment] {
        compactMap { content in
            if case .image(let attachment) = content {
                return attachment
            }
            return nil
        }
    }

    /// 检查是否包含图片
    var hasImages: Bool {
        contains { content in
            if case .image = content {
                return true
            }
            return false
        }
    }
}
