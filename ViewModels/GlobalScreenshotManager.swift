import Foundation
import AppKit

/// 全局截图管理器
/// 负责协调截图功能的整个生命周期：快捷键监听、权限检查、区域选择、截图执行和剪贴板保存
@MainActor
class GlobalScreenshotManager: ObservableObject {

    static let shared = GlobalScreenshotManager()

    @Published var isCapturing = false

    private var hotkeyManager: GlobalHotkeyManager?
    private var overlayWindow: ScreenshotOverlayWindow?
    private let screenshotCapture = ScreenshotCapture()

    private var currentKeyCode: UInt16?
    private var currentModifiers: UInt32 = 0

    // 保存需要隐藏的窗口列表，以便稍后恢复
    private var hiddenWindows: [NSWindow] = []

    private init() {
        print("🎬 [GlobalScreenshot] 初始化截图管理器")
        loadHotkeySettings()
        setupHotkey()

        // 监听设置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsChanged),
            name: NSNotification.Name("ScreenshotHotkeySettingsChanged"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        hotkeyManager?.stop()
    }

    // MARK: - Hotkey Management

    private func loadHotkeySettings() {
        if let keyCode = UserDefaults.standard.object(forKey: "screenshotHotkeyCode") as? UInt16 {
            currentKeyCode = keyCode
        } else {
            // 默认快捷键: ⌘⇧A (Command + Shift + A)
            currentKeyCode = 0  // 'A' key
        }

        currentModifiers = UserDefaults.standard.object(forKey: "screenshotHotkeyModifiers") as? UInt32
            ?? (UInt32(NX_COMMANDMASK) | UInt32(NX_SHIFTMASK))  // ⌘⇧

        print("⌨️ [GlobalScreenshot] 加载快捷键配置:")
        print("  - KeyCode: \(currentKeyCode ?? 0)")
        print("  - Modifiers: \(String(format: "0x%08X", currentModifiers))")
    }

    @objc private func hotkeySettingsChanged() {
        print("🔄 [GlobalScreenshot] 截图快捷键设置已更改")
        loadHotkeySettings()
        hotkeyManager?.stop()
        setupHotkey()
    }

    private func setupHotkey() {
        // 创建独立的快捷键管理器实例
        hotkeyManager = GlobalHotkeyManager()

        // 配置快捷键
        if let keyCode = currentKeyCode {
            // 有具体按键：修饰键 + 按键组合
            hotkeyManager?.setHotkey(keyCode: keyCode, modifiers: currentModifiers)
        } else {
            // 仅修饰键
            hotkeyManager?.setHotkey(keyCode: nil, modifiers: currentModifiers)
        }

        // 设置回调（仅需要按下事件，不需要释放）
        hotkeyManager?.onHotkeyPressed = { [weak self] in
            Task { @MainActor in
                self?.startScreenshot()
            }
        }

        hotkeyManager?.start()
        print("✅ [GlobalScreenshot] 截图快捷键已启动")
    }

    // MARK: - Screenshot Workflow

    private func startScreenshot() {
        guard !isCapturing else {
            print("⚠️ [GlobalScreenshot] 截图已在进行中")
            return
        }

        print("📸 [GlobalScreenshot] 开始截图流程")

        // 检查屏幕录制权限
        if !ScreenRecordingPermissionHelper.checkAndRequestPermission() {
            print("❌ [GlobalScreenshot] 缺少屏幕录制权限")
            return
        }

        isCapturing = true

        // 隐藏所有应用窗口（除了即将创建的 overlay 窗口）
        hideApplicationWindows()

        // 显示区域选择窗口
        overlayWindow = ScreenshotOverlayWindow()

        overlayWindow?.onRegionSelected = { [weak self] rect in
            Task {
                await self?.captureRegion(rect)
            }
        }

        overlayWindow?.onCancelled = { [weak self] in
            self?.cancelScreenshot()
        }

        overlayWindow?.show()
    }

    /// 隐藏所有应用窗口（保存引用以便稍后恢复）
    private func hideApplicationWindows() {
        hiddenWindows = NSApp.windows.filter { window in
            // 只隐藏可见的、非 overlay 的窗口
            window.isVisible && !(window is ScreenshotOverlayWindow)
        }

        for window in hiddenWindows {
            window.orderOut(nil)
        }

        print("🙈 [GlobalScreenshot] 已隐藏 \(hiddenWindows.count) 个应用窗口")
    }

    /// 恢复之前隐藏的应用窗口
    private func restoreApplicationWindows() {
        for window in hiddenWindows {
            window.orderFront(nil)
        }

        print("👁️ [GlobalScreenshot] 已恢复 \(hiddenWindows.count) 个应用窗口")
        hiddenWindows.removeAll()
    }

    @available(macOS 13.0, *)
    private func captureRegion(_ rect: CGRect) async {
        print("📸 [GlobalScreenshot] 用户选择区域: \(rect)")

        // 验证区域有效性
        guard screenshotCapture.isValidRect(rect) else {
            print("❌ [GlobalScreenshot] 无效的截图区域")
            showErrorAlert(message: "选择的区域无效，请重试")
            resetState()
            return
        }

        // 隐藏选择窗口
        overlayWindow?.hide()

        // 短暂延迟确保窗口完全隐藏
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 秒

        // 执行截图（会自动排除应用窗口）
        guard let image = await screenshotCapture.capture(rect: rect) else {
            print("❌ [GlobalScreenshot] 截图失败")
            showErrorAlert(message: "截图失败，请重试")
            resetState()
            return
        }

        // 保存到剪贴板
        ClipboardHelper.copyImage(image)
        print("✅ [GlobalScreenshot] 截图已保存到剪贴板")

        // 显示成功反馈
        showSuccessFeedback()

        resetState()
    }

    private func cancelScreenshot() {
        print("🚫 [GlobalScreenshot] 用户取消截图")
        resetState()
    }

    private func resetState() {
        overlayWindow?.hide()
        overlayWindow = nil
        isCapturing = false

        // 不自动恢复窗口，保持隐藏状态
        // 用户可以通过 Dock 图标或 Cmd+Tab 来重新显示应用
        hiddenWindows.removeAll()
    }

    // MARK: - User Feedback

    private func showSuccessFeedback() {
        // 播放系统提示音
        NSSound.beep()

        // 可选：显示短暂的成功通知
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let notification = NSUserNotification()
            notification.title = "截图成功"
            notification.informativeText = "截图已保存到剪贴板"
            notification.soundName = nil  // 已经播放过提示音了

            NSUserNotificationCenter.default.deliver(notification)
        }
    }

    private func showErrorAlert(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "截图失败"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }

    // MARK: - Public Methods

    /// 手动触发截图（用于测试或其他触发方式）
    func triggerScreenshot() {
        startScreenshot()
    }

    /// 停止快捷键监听
    func stop() {
        hotkeyManager?.stop()
        print("⏹️ [GlobalScreenshot] 截图功能已停止")
    }

    /// 重新启动快捷键监听
    func restart() {
        hotkeyManager?.stop()
        setupHotkey()
        print("♻️ [GlobalScreenshot] 截图功能已重启")
    }
}
