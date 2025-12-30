import Foundation
import AppKit
import AVFoundation

/// 屏幕录制权限管理工具类
class ScreenRecordingPermissionHelper {

    /// 检查是否已授予屏幕录制权限
    /// - Returns: 如果有权限返回 true，否则返回 false
    static func checkPermission() -> Bool {
        if #available(macOS 11.0, *) {
            let hasPermission = CGPreflightScreenCaptureAccess()
            print("🔐 [ScreenPermission] 屏幕录制权限状态: \(hasPermission ? "已授予" : "未授予")")
            return hasPermission
        } else {
            // macOS 10.15 以下版本不需要显式权限
            return true
        }
    }

    /// 请求屏幕录制权限
    /// 注意：首次请求会弹出系统对话框，用户授权后需要重启应用才能生效
    static func requestPermission() {
        if #available(macOS 11.0, *) {
            print("📝 [ScreenPermission] 请求屏幕录制权限...")
            CGRequestScreenCaptureAccess()
        }
    }

    /// 显示权限引导对话框
    /// 当检测到权限未授予时，向用户展示如何授权的说明
    static func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要屏幕录制权限"
            alert.informativeText = """
            截图功能需要屏幕录制权限才能工作。

            请按以下步骤操作：
            1. 点击下方"打开系统设置"按钮
            2. 在"隐私与安全性 → 屏幕录制"中找到 VolcanoChat
            3. 勾选 VolcanoChat 旁边的复选框
            4. 重启应用以使权限生效

            如果列表中没有 VolcanoChat，请先尝试使用截图功能，系统会自动添加。
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                openSystemPreferences()
            }
        }
    }

    /// 打开系统设置的屏幕录制权限页面
    private static func openSystemPreferences() {
        // macOS 13+ 使用新的设置 URL 格式
        if #available(macOS 13.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        } else {
            // macOS 12 及以下使用旧格式
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }

        print("🔗 [ScreenPermission] 已打开系统设置")
    }

    /// 检查权限状态并在需要时显示引导
    /// - Returns: 如果有权限返回 true，否则显示引导对话框并返回 false
    static func checkAndRequestPermission() -> Bool {
        let hasPermission = checkPermission()

        if !hasPermission {
            print("⚠️ [ScreenPermission] 缺少屏幕录制权限")
            requestPermission()
            showPermissionAlert()
            return false
        }

        return true
    }

    /// 显示权限说明（不带系统设置跳转）
    /// 用于首次使用前的友好提示
    static func showInfoAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "关于屏幕录制权限"
            alert.informativeText = """
            截图功能需要"屏幕录制"权限来捕获屏幕内容。

            当您首次使用截图功能时，系统会自动弹出权限请求对话框。
            请在对话框中点击"允许"以启用此功能。

            您可以随时在"系统设置 → 隐私与安全性 → 屏幕录制"中管理此权限。
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "我知道了")
            alert.runModal()
        }
    }
}
