import Foundation
import AppKit

/// 全局截图管理器
/// 负责协调截图功能的整个生命周期：快捷键监听、权限检查、区域选择、截图执行和剪贴板保存
@MainActor
class GlobalScreenshotManager: ObservableObject {

    static let shared = GlobalScreenshotManager()

    @Published var isCapturing = false
    @Published var isRecording = false  // 录音状态

    private var hotkeyManager: GlobalHotkeyManager?
    private var overlayWindow: ScreenshotOverlayWindow?
    private let screenshotCapture = ScreenshotCapture()
    private let audioRecorder = AudioRecorder()
    private let conversationManager = ConversationManager.shared
    private let asrService = VolcanoASRService.shared

    private var currentKeyCode: UInt16?
    private var currentModifiers: UInt32 = 0

    // 保存需要隐藏的窗口列表，以便稍后恢复
    private var hiddenWindows: [NSWindow] = []

    // 录音相关
    private var currentRecordingURL: URL?
    private var pendingScreenshotResult: ScreenshotResult?  // 等待语音识别的截图结果

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

        overlayWindow?.onRegionSelected = { [weak self] result in
            Task {
                await self?.captureRegion(result)
            }
        }

        overlayWindow?.onCancelled = { [weak self] in
            self?.cancelScreenshot()
        }

        overlayWindow?.onSelectionCompleted = { [weak self] result in
            // 保存截图结果，用于后续语音录音
            self?.pendingScreenshotResult = result
            print("✅ [GlobalScreenshot] 选区已完成，保存截图结果")
            print("  - 区域: \(result.rect)")
            print("  - 涂鸦数量: \(result.drawings.count)")
        }

        overlayWindow?.onDrawingsChanged = { [weak self] result in
            // 涂鸦更新时，更新截图结果
            self?.pendingScreenshotResult = result
            print("🎨 [GlobalScreenshot] 涂鸦已更新")
            print("  - 涂鸦数量: \(result.drawings.count)")
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
    private func captureRegion(_ result: ScreenshotResult) async {
        print("📸 [GlobalScreenshot] 用户选择区域: \(result.rect)")
        print("🎨 [GlobalScreenshot] 涂鸦路径数量: \(result.drawings.count)")

        // 验证区域有效性
        guard screenshotCapture.isValidRect(result.rect) else {
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
        guard var image = await screenshotCapture.capture(rect: result.rect) else {
            print("❌ [GlobalScreenshot] 截图失败")
            showErrorAlert(message: "截图失败，请重试")
            resetState()
            return
        }

        // 如果有涂鸦，将涂鸦渲染到图片上
        if !result.drawings.isEmpty {
            image = renderDrawingsOnImage(image, drawings: result.drawings, rect: result.rect)
            print("✅ [GlobalScreenshot] 涂鸦已渲染到截图")
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

    /// 将涂鸦路径渲染到截图上
    private func renderDrawingsOnImage(_ image: NSImage, drawings: [DrawingPath], rect: CGRect) -> NSImage {
        // 创建新图片
        let newImage = NSImage(size: image.size)

        newImage.lockFocus()

        // 绘制原始图片
        image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1.0)

        // 设置绘制上下文
        guard let context = NSGraphicsContext.current?.cgContext else {
            newImage.unlockFocus()
            return image
        }

        // 配置绘制样式（红色，3像素宽）
        context.setStrokeColor(NSColor.red.cgColor)
        context.setLineWidth(3.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // 绘制所有涂鸦路径
        for path in drawings {
            guard !path.points.isEmpty else { continue }

            // 将屏幕坐标转换为图片坐标
            // 注意：NSImage 坐标系是左下角为原点，Y轴向上
            // 屏幕坐标系是左上角为原点，Y轴向下
            let imagePoints = path.points.map { point in
                CGPoint(
                    x: point.x - rect.minX,
                    y: image.size.height - (point.y - rect.minY)  // 翻转 Y 轴
                )
            }

            context.beginPath()
            context.move(to: imagePoints[0])
            for point in imagePoints.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
        }

        newImage.unlockFocus()

        return newImage
    }

    // MARK: - Voice Recording

    /// 开始语音录音（在截图状态中）
    private func startVoiceRecording(with result: ScreenshotResult) {
        guard !isRecording else {
            print("⚠️ [GlobalScreenshot] 已经在录音中")
            return
        }

        print("🎤 [GlobalScreenshot] 开始语音录音")
        print("📸 [GlobalScreenshot] 保存截图结果:")
        print("  - 区域: \(result.rect)")
        print("  - 涂鸦数量: \(result.drawings.count)")

        // 保存截图结果，等待语音识别完成后一起发送
        pendingScreenshotResult = result

        // 检查麦克风权限
        audioRecorder.requestPermission { [weak self] granted in
            guard let self = self else { return }

            if !granted {
                print("❌ [GlobalScreenshot] 麦克风权限被拒绝")
                Task { @MainActor in
                    self.showMicrophoneAlert()
                    self.pendingScreenshotResult = nil
                }
                return
            }

            Task { @MainActor in
                self.isRecording = true

                // 开始录音
                if let url = self.audioRecorder.startRecording() {
                    self.currentRecordingURL = url
                    print("✅ [GlobalScreenshot] 录音已开始，文件: \(url.lastPathComponent)")
                } else {
                    print("❌ [GlobalScreenshot] 录音启动失败")
                    self.isRecording = false
                    self.pendingScreenshotResult = nil
                }
            }
        }
    }

    /// 停止语音录音并发送截图+语音内容
    private func stopVoiceRecording() async {
        guard isRecording else {
            print("⚠️ [GlobalScreenshot] 没有在录音")
            return
        }

        print("🎤 [GlobalScreenshot] 停止语音录音")
        isRecording = false

        // 停止录音并获取URL
        guard let audioURL = audioRecorder.stopRecording() else {
            print("❌ [GlobalScreenshot] 录音文件不存在")
            pendingScreenshotResult = nil
            return
        }

        print("📁 [GlobalScreenshot] 录音文件路径: \(audioURL.path)")

        // 检查是否有待发送的截图结果
        guard let screenshotResult = pendingScreenshotResult else {
            print("❌ [GlobalScreenshot] 没有待发送的截图")
            print("⚠️ [GlobalScreenshot] pendingScreenshotResult 为 nil")
            return
        }

        print("✅ [GlobalScreenshot] 找到待发送的截图结果")
        print("  - 区域: \(screenshotResult.rect)")
        print("  - 涂鸦数量: \(screenshotResult.drawings.count)")

        // 隐藏选择窗口
        overlayWindow?.hide()

        // 短暂延迟确保窗口完全隐藏
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 秒

        print("📸 [GlobalScreenshot] 开始执行截图...")

        // 执行截图（会自动排除应用窗口）
        guard var image = await screenshotCapture.capture(rect: screenshotResult.rect) else {
            print("❌ [GlobalScreenshot] 截图失败")
            showErrorAlert(message: "截图失败，请重试")
            resetState()
            pendingScreenshotResult = nil
            return
        }

        print("✅ [GlobalScreenshot] 截图执行成功")
        print("  - 图片尺寸: \(image.size.width) x \(image.size.height)")

        // 如果有涂鸦，将涂鸦渲染到图片上
        if !screenshotResult.drawings.isEmpty {
            print("🎨 [GlobalScreenshot] 开始渲染涂鸦...")
            image = renderDrawingsOnImage(image, drawings: screenshotResult.drawings, rect: screenshotResult.rect)
            print("✅ [GlobalScreenshot] 涂鸦已渲染到截图")
        }

        print("🖼️ [GlobalScreenshot] 开始转换图片为 PNG...")

        // 创建图片附件
        guard let imageData = image.tiffRepresentation else {
            print("❌ [GlobalScreenshot] TIFF 转换失败")
            showErrorAlert(message: "图片处理失败，请重试")
            resetState()
            pendingScreenshotResult = nil
            return
        }

        print("✅ [GlobalScreenshot] TIFF 数据大小: \(imageData.count) bytes")

        guard let bitmapRep = NSBitmapImageRep(data: imageData) else {
            print("❌ [GlobalScreenshot] BitmapRep 创建失败")
            showErrorAlert(message: "图片处理失败，请重试")
            resetState()
            pendingScreenshotResult = nil
            return
        }

        print("✅ [GlobalScreenshot] BitmapRep 创建成功")

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("❌ [GlobalScreenshot] PNG 转换失败")
            showErrorAlert(message: "图片处理失败，请重试")
            resetState()
            pendingScreenshotResult = nil
            return
        }

        print("✅ [GlobalScreenshot] PNG 转换成功，数据大小: \(pngData.count) bytes")

        let imageAttachment = ImageAttachment(
            data: pngData,
            mimeType: "image/png",
            width: Int(image.size.width),
            height: Int(image.size.height)
        )

        print("✅ [GlobalScreenshot] 图片附件已创建:")
        print("  - 尺寸: \(Int(image.size.width)) x \(Int(image.size.height))")
        print("  - 数据大小: \(pngData.count) bytes")

        do {
            // 语音转文字
            let recognizedText = try await asrService.recognizeSpeech(audioURL: audioURL)

            if recognizedText.isEmpty {
                print("⚠️ [GlobalScreenshot] 语音识别为空")
                showErrorAlert(message: "无法识别语音内容")
                resetState()
                pendingScreenshotResult = nil
                return
            }

            print("✅ [GlobalScreenshot] 语音识别成功: \(recognizedText)")
            print("📤 [GlobalScreenshot] 准备发送消息:")
            print("  - 文本: \(recognizedText)")
            print("  - 图片数量: 1")

            // 发送消息（图片 + 文本）
            await conversationManager.sendMessage(text: recognizedText, images: [imageAttachment])
            print("✅ [GlobalScreenshot] 截图和语音内容已发送")

            // 恢复应用窗口（让用户看到聊天界面）
            restoreApplicationWindows()

            // 显示成功反馈
            showSuccessFeedback(message: "截图和语音已发送给 AI")

            resetState()
            pendingScreenshotResult = nil

        } catch {
            print("❌ [GlobalScreenshot] 语音识别失败: \(error)")
            showErrorAlert(message: "语音识别失败: \(error.localizedDescription)")

            // 恢复应用窗口
            restoreApplicationWindows()

            resetState()
            pendingScreenshotResult = nil
        }
    }

    private func showMicrophoneAlert() {
        let alert = NSAlert()
        alert.messageText = "需要麦克风权限"
        alert.informativeText = "语音输入功能需要麦克风权限。\n\n请前往：\n系统设置 → 隐私与安全性 → 麦克风\n\n将 VolcanoChat 添加到列表中。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
        }
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
        // 静默成功，不显示任何提示
    }

    private func showSuccessFeedback(message: String) {
        // 静默成功，不显示任何提示
    }

    private func showErrorAlert(message: String) {
        Task { @MainActor in
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

    /// 处理全局录音快捷键按下（从 GlobalRecordingManager 转发）
    func handleGlobalRecordingPressed() {
        guard isCapturing else {
            print("⚠️ [GlobalScreenshot] 无法处理录音：未在截图状态")
            return
        }

        guard let result = pendingScreenshotResult else {
            print("⚠️ [GlobalScreenshot] 无法处理录音：无待处理的截图结果")
            return
        }

        print("✅ [GlobalScreenshot] 接收到全局录音按下事件")
        startVoiceRecording(with: result)
    }

    /// 处理全局录音快捷键释放（从 GlobalRecordingManager 转发）
    func handleGlobalRecordingReleased() {
        guard isRecording else {
            print("⚠️ [GlobalScreenshot] 无法处理录音释放：未在录音状态")
            return
        }

        print("✅ [GlobalScreenshot] 接收到全局录音释放事件")
        Task {
            await stopVoiceRecording()
        }
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
