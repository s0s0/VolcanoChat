import AppKit

/// 剪贴板操作工具类
class ClipboardHelper {

    /// 将图像复制到系统剪贴板
    /// - Parameter image: 要复制的图像
    static func copyImage(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        // 提供多种格式以确保兼容性
        var objects: [NSPasteboardWriting] = []

        // 添加原始 NSImage 对象
        objects.append(image)

        // 添加 TIFF 格式（高质量，保留所有信息）
        if let tiffData = image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }

        // 添加 PNG 格式（通用格式）
        if let pngData = image.pngData() {
            pasteboard.setData(pngData, forType: .png)
        }

        pasteboard.writeObjects(objects)

        print("✅ [Clipboard] 图像已复制到剪贴板")
    }

    /// 检查剪贴板是否包含图像
    /// - Returns: 如果剪贴板包含图像则返回 true
    static func hasImage() -> Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.canReadObject(forClasses: [NSImage.self], options: nil)
    }

    /// 从剪贴板读取图像
    /// - Returns: 剪贴板中的图像，如果不存在则返回 nil
    static func readImage() -> NSImage? {
        let pasteboard = NSPasteboard.general
        guard let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
              let image = objects.first as? NSImage else {
            return nil
        }
        return image
    }
}

// MARK: - NSImage Extension

extension NSImage {
    /// 将图像转换为 PNG 数据
    /// - Returns: PNG 格式的数据，转换失败则返回 nil
    func pngData() -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        bitmap.size = self.size  // 确保使用正确的尺寸

        return bitmap.representation(using: .png, properties: [:])
    }

    /// 将图像转换为 JPEG 数据
    /// - Parameter compressionQuality: 压缩质量 (0.0 - 1.0)
    /// - Returns: JPEG 格式的数据，转换失败则返回 nil
    func jpegData(compressionQuality: CGFloat = 0.9) -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        bitmap.size = self.size

        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
}
