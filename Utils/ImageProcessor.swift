import Foundation
import AppKit
import UniformTypeIdentifiers

/// 图片处理工具类
class ImageProcessor {

    // MARK: - 图片压缩

    /// 压缩图片到指定大小以下
    /// - Parameters:
    ///   - image: 原始图片
    ///   - maxSizeMB: 最大文件大小（MB）
    ///   - format: 输出格式（默认 JPEG）
    /// - Returns: 压缩后的图片数据
    static func compress(image: NSImage, maxSizeMB: Double = 5.0, format: ImageFormat = .jpeg) -> Data? {
        let maxBytes = Int(maxSizeMB * 1024 * 1024)

        // 首先尝试原始质量
        if let data = convertToData(image: image, format: format, quality: 1.0),
           data.count <= maxBytes {
            return data
        }

        // 二分查找最佳压缩质量
        var low: CGFloat = 0.1
        var high: CGFloat = 1.0
        var bestData: Data?

        while high - low > 0.05 {
            let mid = (low + high) / 2
            guard let data = convertToData(image: image, format: format, quality: mid) else {
                high = mid
                continue
            }

            if data.count <= maxBytes {
                bestData = data
                low = mid
            } else {
                high = mid
            }
        }

        return bestData
    }

    /// 转换图片为指定格式的数据
    private static func convertToData(image: NSImage, format: ImageFormat, quality: CGFloat) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        bitmapRep.size = image.size

        switch format {
        case .jpeg:
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        case .png:
            return bitmapRep.representation(using: .png, properties: [:])
        }
    }

    // MARK: - 缩略图生成

    /// 生成缩略图
    /// - Parameters:
    ///   - image: 原始图片
    ///   - maxSize: 最大尺寸
    /// - Returns: 缩略图
    static func generateThumbnail(from image: NSImage, maxSize: CGSize) -> NSImage {
        let originalSize = image.size
        let scale = min(maxSize.width / originalSize.width, maxSize.height / originalSize.height)

        // 如果图片已经足够小，直接返回
        if scale >= 1.0 {
            return image
        }

        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: originalSize),
                   operation: .copy,
                   fraction: 1.0)
        thumbnail.unlockFocus()

        return thumbnail
    }

    // MARK: - Base64 编码

    /// 转换为 base64 Data URL
    /// - Parameters:
    ///   - data: 图片数据
    ///   - mimeType: MIME 类型
    /// - Returns: base64 Data URL
    static func toBase64DataURL(data: Data, mimeType: String) -> String {
        let base64String = data.base64EncodedString()
        return "data:\(mimeType);base64,\(base64String)"
    }

    // MARK: - 格式检测和验证

    /// 检测图片的 MIME 类型
    /// - Parameter data: 图片数据
    /// - Returns: MIME 类型，如果无法识别则返回 nil
    static func detectMimeType(data: Data) -> String? {
        guard data.count >= 12 else { return nil }

        let bytes = [UInt8](data.prefix(12))

        // PNG
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        }

        // JPEG
        if bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF {
            return "image/jpeg"
        }

        // GIF
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 {
            return "image/gif"
        }

        // WebP
        if bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50 {
            return "image/webp"
        }

        return nil
    }

    /// 验证图片格式是否支持
    /// - Parameter data: 图片数据
    /// - Returns: 如果支持返回 MIME 类型，否则返回 nil
    static func validateImageFormat(data: Data) -> String? {
        guard let mimeType = detectMimeType(data: data) else {
            return nil
        }

        let supportedFormats = ["image/png", "image/jpeg", "image/gif", "image/webp"]
        return supportedFormats.contains(mimeType) ? mimeType : nil
    }

    /// 从 NSImage 创建图片附件
    /// - Parameters:
    ///   - image: NSImage 对象
    ///   - preferredFormat: 首选格式（默认自动选择）
    /// - Returns: ImageAttachment，如果失败返回 nil
    static func createAttachment(from image: NSImage, preferredFormat: ImageFormat = .jpeg) -> ImageAttachment? {
        // 压缩图片
        guard let data = compress(image: image, maxSizeMB: 5.0, format: preferredFormat) else {
            return nil
        }

        let mimeType: String
        switch preferredFormat {
        case .jpeg:
            mimeType = "image/jpeg"
        case .png:
            mimeType = "image/png"
        }

        return ImageAttachment(
            data: data,
            mimeType: mimeType,
            width: Int(image.size.width),
            height: Int(image.size.height)
        )
    }

    /// 从文件 URL 加载图片附件
    /// - Parameter url: 文件 URL
    /// - Returns: ImageAttachment，如果失败返回 nil
    static func loadAttachment(from url: URL) -> ImageAttachment? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        // 验证格式
        guard let mimeType = validateImageFormat(data: data) else {
            return nil
        }

        // 获取图片尺寸
        var width: Int?
        var height: Int?
        if let image = NSImage(data: data) {
            width = Int(image.size.width)
            height = Int(image.size.height)

            // 如果图片太大，需要压缩
            if data.count > 5 * 1024 * 1024 {
                return createAttachment(from: image, preferredFormat: mimeType.contains("png") ? .png : .jpeg)
            }
        }

        return ImageAttachment(
            data: data,
            mimeType: mimeType,
            width: width,
            height: height
        )
    }

    /// 从粘贴板加载图片附件
    /// - Returns: ImageAttachment 数组
    static func loadAttachmentsFromPasteboard() -> [ImageAttachment] {
        let pasteboard = NSPasteboard.general
        var attachments: [ImageAttachment] = []

        // 尝试读取 PNG
        if let data = pasteboard.data(forType: .png),
           let attachment = createAttachmentFromData(data, preferredMimeType: "image/png") {
            attachments.append(attachment)
        }

        // 尝试读取 TIFF
        if attachments.isEmpty,
           let data = pasteboard.data(forType: .tiff),
           let image = NSImage(data: data),
           let attachment = createAttachment(from: image) {
            attachments.append(attachment)
        }

        // 尝试读取文件 URL
        if attachments.isEmpty,
           let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            for url in urls.prefix(5) {  // 最多 5 张
                if let attachment = loadAttachment(from: url) {
                    attachments.append(attachment)
                }
            }
        }

        return attachments
    }

    private static func createAttachmentFromData(_ data: Data, preferredMimeType: String) -> ImageAttachment? {
        guard let mimeType = validateImageFormat(data: data) else {
            return nil
        }

        var width: Int?
        var height: Int?
        if let image = NSImage(data: data) {
            width = Int(image.size.width)
            height = Int(image.size.height)
        }

        return ImageAttachment(
            data: data,
            mimeType: mimeType,
            width: width,
            height: height
        )
    }

    // MARK: - 支持的格式

    enum ImageFormat {
        case jpeg
        case png
    }
}
