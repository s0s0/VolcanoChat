import Foundation
import AppKit
import ScreenCaptureKit

/// 屏幕截图捕获工具类
class ScreenshotCapture {

    /// 捕获指定区域的屏幕截图
    /// - Parameter rect: 要捕获的屏幕区域（屏幕坐标系）
    /// - Returns: 捕获的图像，失败则返回 nil
    @available(macOS 13.0, *)
    func capture(rect: CGRect) async -> NSImage? {
        print("📸 [ScreenshotCapture] 开始捕获区域: \(rect)")

        // 验证区域有效性
        guard rect.width > 0 && rect.height > 0 else {
            print("❌ [ScreenshotCapture] 无效的捕获区域")
            return nil
        }

        // 使用 ScreenCaptureKit API
        return try? await captureWithScreenCaptureKit(rect: rect)
    }

    // MARK: - ScreenCaptureKit Implementation (macOS 13+)

    @available(macOS 13.0, *)
    private func captureWithScreenCaptureKit(rect: CGRect) async throws -> NSImage? {
        print("📸 [ScreenshotCapture] 使用 ScreenCaptureKit API")

        // 获取所有可共享内容
        let content = try await SCShareableContent.current

        // 找到包含指定区域的显示器
        guard let display = findDisplay(for: rect, in: content.displays) else {
            print("❌ [ScreenshotCapture] 未找到对应的显示器")
            return nil
        }

        print("📺 [ScreenshotCapture] 使用显示器: \(display.displayID)")

        // 获取当前应用的所有窗口，在截图时排除
        let currentAppWindows = getCurrentAppWindows(from: content)
        print("🪟 [ScreenshotCapture] 排除 \(currentAppWindows.count) 个应用窗口")

        // 创建内容过滤器（排除当前应用的窗口）
        let filter = SCContentFilter(display: display, excludingWindows: currentAppWindows)

        // 转换坐标到显示器相对坐标
        let displayRect = convertToDisplayCoordinates(rect: rect, display: display)

        // 获取对应 NSScreen 的缩放比例
        let scale = getScaleForDisplay(display)

        // 配置截图参数
        let config = SCStreamConfiguration()
        config.sourceRect = displayRect
        config.width = Int(displayRect.width * scale)
        config.height = Int(displayRect.height * scale)
        config.scalesToFit = false
        config.showsCursor = false  // 不显示鼠标光标

        print("📐 [ScreenshotCapture] 捕获配置:")
        print("  - 源区域: \(displayRect)")
        print("  - 输出尺寸: \(config.width) x \(config.height)")
        print("  - 缩放比例: \(scale)")

        // 执行截图
        let cgImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        // 转换为 NSImage
        let size = NSSize(width: displayRect.width, height: displayRect.height)
        let image = NSImage(cgImage: cgImage, size: size)

        print("✅ [ScreenshotCapture] 截图成功")
        return image
    }

    // MARK: - Helper Methods

    /// 找到包含指定区域的显示器
    @available(macOS 13.0, *)
    private func findDisplay(for rect: CGRect, in displays: [SCDisplay]) -> SCDisplay? {
        // 找到包含矩形区域中心点的显示器
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)

        for display in displays {
            if display.frame.contains(centerPoint) {
                return display
            }
        }

        print("⚠️ [ScreenshotCapture] 未找到包含中心点的显示器，使用主显示器")
        return displays.first
    }

    /// 将屏幕绝对坐标转换为显示器相对坐标
    @available(macOS 13.0, *)
    private func convertToDisplayCoordinates(rect: CGRect, display: SCDisplay) -> CGRect {
        let displayFrame = display.frame

        return CGRect(
            x: rect.origin.x - displayFrame.origin.x,
            y: rect.origin.y - displayFrame.origin.y,
            width: rect.width,
            height: rect.height
        )
    }

    /// 获取当前应用的所有窗口
    @available(macOS 13.0, *)
    private func getCurrentAppWindows(from content: SCShareableContent) -> [SCWindow] {
        let currentPID = NSRunningApplication.current.processIdentifier

        return content.windows.filter { window in
            window.owningApplication?.processID == currentPID
        }
    }

    /// 获取指定 SCDisplay 对应的 NSScreen 缩放比例
    @available(macOS 13.0, *)
    private func getScaleForDisplay(_ display: SCDisplay) -> CGFloat {
        // 通过显示器 ID 查找对应的 NSScreen
        let displayID = display.displayID

        for screen in NSScreen.screens {
            // NSScreen 的 deviceDescription 包含显示器 ID
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
               screenNumber == displayID {
                return screen.backingScaleFactor
            }
        }

        // 如果没找到匹配的屏幕，返回默认值 2.0（Retina）
        return NSScreen.main?.backingScaleFactor ?? 2.0
    }

    /// 验证截图区域是否在任何显示器范围内
    func isValidRect(_ rect: CGRect) -> Bool {
        guard rect.width > 0 && rect.height > 0 else {
            return false
        }

        // 检查是否与任何屏幕相交
        for screen in NSScreen.screens {
            if screen.frame.intersects(rect) {
                return true
            }
        }

        return false
    }
}
