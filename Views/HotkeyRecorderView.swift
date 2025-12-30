import SwiftUI
import Carbon

struct HotkeyRecorderView: View {
    @Binding var keyCode: UInt16?
    @Binding var modifiers: UInt32
    @State private var isRecording = false
    @State private var displayText: String = ""
    @State private var tempKeyCode: UInt16?
    @State private var tempModifiers: UInt32 = 0
    @State private var eventMonitor: Any?
    @State private var showConflictAlert = false
    @State private var conflictMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 录制区域
                HStack(spacing: 4) {
                    if isRecording {
                        // 录制状态：显示实时预览
                        if tempModifiers == 0 && tempKeyCode == nil {
                            Text("请按下快捷键组合...")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(buildKeyDisplayParts(), id: \.self) { part in
                                KeyCapView(text: part, isRecording: true)
                            }
                        }
                    } else {
                        // 非录制状态：显示已设置的快捷键
                        if displayText.isEmpty {
                            Text("点击录制快捷键")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(buildKeyDisplayParts(), id: \.self) { part in
                                KeyCapView(text: part, isRecording: false)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1.5)
                )
                .onTapGesture {
                    if !isRecording {
                        startRecording()
                    }
                }

                if !displayText.isEmpty && !isRecording {
                    Button(action: clearHotkey) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }

            // 录制提示
            if isRecording {
                Text("按下快捷键组合，松开即保存 • 按 Esc 取消")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            updateDisplayText()
        }
        .alert("快捷键冲突", isPresented: $showConflictAlert) {
            Button("仍然使用", role: .destructive) {
                applyHotkey()
            }
            Button("取消", role: .cancel) {
                // 不应用，保持录制状态
            }
        } message: {
            Text(conflictMessage)
        }
    }

    private func startRecording() {
        isRecording = true
        tempKeyCode = nil
        tempModifiers = 0

        // 创建本地事件监听器（监听按下和松开）
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            if self.isRecording {
                self.handleKeyEvent(event)
                return nil  // 拦截事件
            }
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            let keyCodeValue = event.keyCode

            // ESC 取消录制
            if keyCodeValue == 53 {
                cancelRecording()
                return
            }

            // Delete 清除当前按键
            if keyCodeValue == 51 {
                tempKeyCode = nil
                tempModifiers = event.modifierFlags.carbonModifiers
                return
            }

            // 记录按键和修饰键
            tempKeyCode = keyCodeValue
            tempModifiers = event.modifierFlags.carbonModifiers

        } else if event.type == .keyUp {
            // 松开按键时自动确认（如果已经记录了按键）
            if tempKeyCode != nil {
                confirmHotkey()
            }

        } else if event.type == .flagsChanged {
            // 只更新修饰键状态
            let newModifiers = event.modifierFlags.carbonModifiers

            // 如果是松开所有修饰键（变为0），且之前没有按下普通键，则取消
            if newModifiers == 0 && tempKeyCode == nil && tempModifiers != 0 {
                // 用户只是按了修饰键又松开了，不做任何操作
                tempModifiers = 0
                return
            }

            tempModifiers = newModifiers
        }
    }

    private func confirmHotkey() {
        // 检查快捷键冲突
        if let conflict = SystemHotkeyValidator.checkConflict(keyCode: tempKeyCode, modifiers: tempModifiers) {
            let hotkeyDesc = SystemHotkeyValidator.getHotkeyDescription(keyCode: tempKeyCode, modifiers: tempModifiers)
            conflictMessage = """
            您设置的快捷键 \(hotkeyDesc) 与系统快捷键冲突：

            \(conflict)

            使用此快捷键可能会导致系统功能无法正常工作。
            建议选择其他快捷键组合。
            """
            showConflictAlert = true
        } else {
            // 没有冲突，直接应用
            applyHotkey()
        }
    }

    private func applyHotkey() {
        // 应用录制的快捷键
        keyCode = tempKeyCode
        modifiers = tempModifiers
        stopRecording()
        updateDisplayText()
    }

    private func cancelRecording() {
        // 取消录制，恢复原值
        tempKeyCode = keyCode
        tempModifiers = modifiers
        stopRecording()
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func buildKeyDisplayParts() -> [String] {
        var parts: [String] = []
        let currentModifiers = isRecording ? tempModifiers : modifiers
        let currentKeyCode = isRecording ? tempKeyCode : keyCode

        // 修饰键（按标准顺序）
        if currentModifiers & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }
        if currentModifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }
        if currentModifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }
        if currentModifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }

        // 实际按键
        if let keyCodeValue = currentKeyCode {
            if let keyName = keyCodeToString(keyCodeValue) {
                parts.append(keyName)
            }
        }

        return parts
    }

    private func updateDisplayText() {
        let parts = buildKeyDisplayParts()
        displayText = parts.isEmpty ? "" : parts.joined(separator: " + ")
    }

    private func clearHotkey() {
        keyCode = nil
        modifiers = 0
        displayText = ""
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        let keyCodeMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`",
            36: "⏎", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
            101: "F9", 103: "F11", 105: "F13", 109: "F10", 111: "F12",
            118: "F1", 120: "F2", 122: "F4"
        ]

        return keyCodeMap[keyCode]
    }
}

// MARK: - Key Cap View (按键显示组件)

struct KeyCapView: View {
    let text: String
    let isRecording: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isRecording ? Color.blue.opacity(0.2) : Color.gray.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isRecording ? Color.blue.opacity(0.4) : Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

extension NSEvent.ModifierFlags {
    var carbonModifiers: UInt32 {
        var carbon: UInt32 = 0
        if contains(.command) { carbon |= UInt32(cmdKey) }
        if contains(.option) { carbon |= UInt32(optionKey) }
        if contains(.control) { carbon |= UInt32(controlKey) }
        if contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }
}

// MARK: - System Hotkey Validator

/// 系统快捷键冲突检测器
struct SystemHotkeyValidator {

    /// 检查快捷键是否与系统或其他应用的快捷键冲突
    static func checkConflict(keyCode: UInt16?, modifiers: UInt32) -> String? {
        guard let keyCode = keyCode else {
            return checkModifierOnlyConflict(modifiers: modifiers)
        }

        let hotkeyIdentifier = HotkeyIdentifier(keyCode: keyCode, modifiers: modifiers)

        // 检查系统快捷键
        if let conflict = systemHotkeys[hotkeyIdentifier] {
            return "系统快捷键：\(conflict)"
        }

        // 检查常见应用快捷键
        if let conflict = commonAppHotkeys[hotkeyIdentifier] {
            return "应用快捷键：\(conflict)"
        }

        // 检查用户自定义的系统快捷键
        if let conflict = checkUserCustomHotkeys(keyCode: keyCode, modifiers: modifiers) {
            return "用户自定义：\(conflict)"
        }

        return nil
    }

    private static func checkModifierOnlyConflict(modifiers: UInt32) -> String? {
        if modifiers == UInt32(cmdKey) {
            return "Command（可能与系统手势冲突）"
        }
        if modifiers == UInt32(controlKey) {
            return "Control（通常用于输入法切换）"
        }
        return nil
    }

    /// 检查用户在系统设置中自定义的快捷键
    private static func checkUserCustomHotkeys(keyCode: UInt16, modifiers: UInt32) -> String? {
        // 读取用户自定义快捷键（从系统偏好设置）
        let prefsPath = NSHomeDirectory() + "/Library/Preferences/.GlobalPreferences.plist"

        if let prefs = NSDictionary(contentsOfFile: prefsPath),
           let customShortcuts = prefs["NSUserKeyEquivalents"] as? [String: Any] {
            // 这里包含了用户在各个应用中自定义的菜单快捷键
            // 格式较复杂，这里做简单提示
            if !customShortcuts.isEmpty {
                // 如果用户设置了自定义快捷键，给出提示
                return nil // 暂时不做精确匹配，避免误报
            }
        }

        return nil
    }

    private struct HotkeyIdentifier: Hashable {
        let keyCode: UInt16
        let modifiers: UInt32
    }

    /// macOS 系统快捷键
    private static let systemHotkeys: [HotkeyIdentifier: String] = {
        var hotkeys: [HotkeyIdentifier: String] = [:]

        // 通用快捷键
        hotkeys[HotkeyIdentifier(keyCode: 8, modifiers: UInt32(cmdKey))] = "⌘C - 拷贝"
        hotkeys[HotkeyIdentifier(keyCode: 9, modifiers: UInt32(cmdKey))] = "⌘V - 粘贴"
        hotkeys[HotkeyIdentifier(keyCode: 7, modifiers: UInt32(cmdKey))] = "⌘X - 剪切"
        hotkeys[HotkeyIdentifier(keyCode: 6, modifiers: UInt32(cmdKey))] = "⌘Z - 撤销"
        hotkeys[HotkeyIdentifier(keyCode: 6, modifiers: UInt32(cmdKey) | UInt32(shiftKey))] = "⌘⇧Z - 重做"
        hotkeys[HotkeyIdentifier(keyCode: 0, modifiers: UInt32(cmdKey))] = "⌘A - 全选"
        hotkeys[HotkeyIdentifier(keyCode: 1, modifiers: UInt32(cmdKey))] = "⌘S - 保存"
        hotkeys[HotkeyIdentifier(keyCode: 3, modifiers: UInt32(cmdKey))] = "⌘F - 查找"
        hotkeys[HotkeyIdentifier(keyCode: 5, modifiers: UInt32(cmdKey))] = "⌘G - 查找下一个"
        hotkeys[HotkeyIdentifier(keyCode: 5, modifiers: UInt32(cmdKey) | UInt32(shiftKey))] = "⌘⇧G - 查找上一个"

        // 窗口管理
        hotkeys[HotkeyIdentifier(keyCode: 12, modifiers: UInt32(cmdKey))] = "⌘Q - 退出应用"
        hotkeys[HotkeyIdentifier(keyCode: 13, modifiers: UInt32(cmdKey))] = "⌘W - 关闭窗口"
        hotkeys[HotkeyIdentifier(keyCode: 46, modifiers: UInt32(cmdKey))] = "⌘M - 最小化窗口"
        hotkeys[HotkeyIdentifier(keyCode: 4, modifiers: UInt32(cmdKey))] = "⌘H - 隐藏应用"
        hotkeys[HotkeyIdentifier(keyCode: 4, modifiers: UInt32(cmdKey) | UInt32(optionKey))] = "⌘⌥H - 隐藏其他应用"
        hotkeys[HotkeyIdentifier(keyCode: 45, modifiers: UInt32(cmdKey))] = "⌘N - 新建"
        hotkeys[HotkeyIdentifier(keyCode: 17, modifiers: UInt32(cmdKey))] = "⌘T - 新建标签"

        // 文本编辑
        hotkeys[HotkeyIdentifier(keyCode: 11, modifiers: UInt32(cmdKey))] = "⌘B - 加粗"
        hotkeys[HotkeyIdentifier(keyCode: 34, modifiers: UInt32(cmdKey))] = "⌘I - 斜体"
        hotkeys[HotkeyIdentifier(keyCode: 32, modifiers: UInt32(cmdKey))] = "⌘U - 下划线"

        // 系统功能
        hotkeys[HotkeyIdentifier(keyCode: 49, modifiers: UInt32(cmdKey))] = "⌘Space - Spotlight 搜索"
        hotkeys[HotkeyIdentifier(keyCode: 49, modifiers: UInt32(cmdKey) | UInt32(shiftKey))] = "⌘⇧Space - 输入法切换"
        hotkeys[HotkeyIdentifier(keyCode: 49, modifiers: UInt32(controlKey))] = "⌃Space - 输入法切换"
        hotkeys[HotkeyIdentifier(keyCode: 48, modifiers: UInt32(cmdKey))] = "⌘Tab - 切换应用"
        hotkeys[HotkeyIdentifier(keyCode: 50, modifiers: UInt32(cmdKey))] = "⌘` - 切换窗口"

        // 截图快捷键
        hotkeys[HotkeyIdentifier(keyCode: 20, modifiers: UInt32(cmdKey) | UInt32(shiftKey))] = "⌘⇧3 - 截图全屏"
        hotkeys[HotkeyIdentifier(keyCode: 21, modifiers: UInt32(cmdKey) | UInt32(shiftKey))] = "⌘⇧4 - 截图区域"
        hotkeys[HotkeyIdentifier(keyCode: 23, modifiers: UInt32(cmdKey) | UInt32(shiftKey))] = "⌘⇧5 - 截图工具"

        // Mission Control
        hotkeys[HotkeyIdentifier(keyCode: 126, modifiers: UInt32(controlKey))] = "⌃↑ - Mission Control"
        hotkeys[HotkeyIdentifier(keyCode: 125, modifiers: UInt32(controlKey))] = "⌃↓ - 应用程序窗口"

        // 浏览器常用
        hotkeys[HotkeyIdentifier(keyCode: 15, modifiers: UInt32(cmdKey))] = "⌘R - 刷新"
        hotkeys[HotkeyIdentifier(keyCode: 15, modifiers: UInt32(cmdKey) | UInt32(shiftKey))] = "⌘⇧R - 强制刷新"
        hotkeys[HotkeyIdentifier(keyCode: 37, modifiers: UInt32(cmdKey))] = "⌘L - 地址栏"
        hotkeys[HotkeyIdentifier(keyCode: 2, modifiers: UInt32(cmdKey))] = "⌘D - 添加书签"

        // Finder
        hotkeys[HotkeyIdentifier(keyCode: 31, modifiers: UInt32(cmdKey))] = "⌘O - 打开"
        hotkeys[HotkeyIdentifier(keyCode: 35, modifiers: UInt32(cmdKey))] = "⌘P - 打印"
        hotkeys[HotkeyIdentifier(keyCode: 51, modifiers: UInt32(cmdKey))] = "⌘Delete - 移到废纸篓"
        hotkeys[HotkeyIdentifier(keyCode: 51, modifiers: UInt32(cmdKey) | UInt32(shiftKey))] = "⌘⇧Delete - 清空废纸篓"

        return hotkeys
    }()

    /// 常见第三方应用的快捷键
    private static let commonAppHotkeys: [HotkeyIdentifier: String] = {
        var hotkeys: [HotkeyIdentifier: String] = [:]

        // Alfred（默认快捷键）
        hotkeys[HotkeyIdentifier(keyCode: 49, modifiers: UInt32(optionKey))] = "Alfred - ⌥Space"
        hotkeys[HotkeyIdentifier(keyCode: 49, modifiers: UInt32(cmdKey) | UInt32(optionKey))] = "Alfred - ⌘⌥Space"

        // Raycast（默认快捷键）
        hotkeys[HotkeyIdentifier(keyCode: 49, modifiers: UInt32(cmdKey) | UInt32(controlKey))] = "Raycast - ⌘⌃Space"

        // CleanShot X（默认快捷键）
        hotkeys[HotkeyIdentifier(keyCode: 20, modifiers: UInt32(cmdKey) | UInt32(shiftKey) | UInt32(controlKey))] = "CleanShot X - ⌘⇧⌃3"
        hotkeys[HotkeyIdentifier(keyCode: 21, modifiers: UInt32(cmdKey) | UInt32(shiftKey) | UInt32(controlKey))] = "CleanShot X - ⌘⇧⌃4"

        // Rectangle（窗口管理）
        hotkeys[HotkeyIdentifier(keyCode: 123, modifiers: UInt32(cmdKey) | UInt32(optionKey))] = "Rectangle - ⌘⌥← 左半屏"
        hotkeys[HotkeyIdentifier(keyCode: 124, modifiers: UInt32(cmdKey) | UInt32(optionKey))] = "Rectangle - ⌘⌥→ 右半屏"
        hotkeys[HotkeyIdentifier(keyCode: 126, modifiers: UInt32(cmdKey) | UInt32(optionKey))] = "Rectangle - ⌘⌥↑ 上半屏"
        hotkeys[HotkeyIdentifier(keyCode: 125, modifiers: UInt32(cmdKey) | UInt32(optionKey))] = "Rectangle - ⌘⌥↓ 下半屏"
        hotkeys[HotkeyIdentifier(keyCode: 3, modifiers: UInt32(cmdKey) | UInt32(optionKey))] = "Rectangle - ⌘⌥F 全屏"

        // Magnet（窗口管理）
        hotkeys[HotkeyIdentifier(keyCode: 123, modifiers: UInt32(controlKey) | UInt32(optionKey))] = "Magnet - ⌃⌥← 左半屏"
        hotkeys[HotkeyIdentifier(keyCode: 124, modifiers: UInt32(controlKey) | UInt32(optionKey))] = "Magnet - ⌃⌥→ 右半屏"

        // VS Code（常用快捷键）
        hotkeys[HotkeyIdentifier(keyCode: 35, modifiers: UInt32(cmdKey) | UInt32(shiftKey))] = "VS Code - ⌘⇧P 命令面板"
        hotkeys[HotkeyIdentifier(keyCode: 40, modifiers: UInt32(cmdKey))] = "VS Code - ⌘K 快捷键前缀"
        hotkeys[HotkeyIdentifier(keyCode: 11, modifiers: UInt32(cmdKey) | UInt32(controlKey))] = "VS Code - ⌘⌃B 侧边栏"

        // Xcode（常用快捷键）
        hotkeys[HotkeyIdentifier(keyCode: 15, modifiers: UInt32(cmdKey))] = "Xcode - ⌘R 运行"
        hotkeys[HotkeyIdentifier(keyCode: 11, modifiers: UInt32(cmdKey))] = "Xcode - ⌘B 构建"
        hotkeys[HotkeyIdentifier(keyCode: 47, modifiers: UInt32(cmdKey))] = "Xcode - ⌘. 停止"

        // iTerm2
        hotkeys[HotkeyIdentifier(keyCode: 17, modifiers: UInt32(cmdKey))] = "iTerm2 - ⌘T 新建标签"
        hotkeys[HotkeyIdentifier(keyCode: 2, modifiers: UInt32(cmdKey))] = "iTerm2 - ⌘D 垂直分割"
        hotkeys[HotkeyIdentifier(keyCode: 2, modifiers: UInt32(cmdKey) | UInt32(shiftKey))] = "iTerm2 - ⌘⇧D 水平分割"

        // 1Password
        hotkeys[HotkeyIdentifier(keyCode: 42, modifiers: UInt32(cmdKey) | UInt32(optionKey))] = "1Password - ⌘⌥\\ 快速访问"

        // Paste（剪贴板工具）
        hotkeys[HotkeyIdentifier(keyCode: 9, modifiers: UInt32(cmdKey) | UInt32(shiftKey))] = "Paste - ⌘⇧V 剪贴板历史"

        // PopClip
        hotkeys[HotkeyIdentifier(keyCode: 46, modifiers: UInt32(cmdKey) | UInt32(shiftKey))] = "PopClip - ⌘⇧M 显示菜单"

        return hotkeys
    }()

    /// 获取快捷键的可读描述
    static func getHotkeyDescription(keyCode: UInt16?, modifiers: UInt32) -> String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }

        if let keyCode = keyCode, let keyName = keyCodeToString(keyCode) {
            parts.append(keyName)
        }

        return parts.joined(separator: " + ")
    }

    private static func keyCodeToString(_ keyCode: UInt16) -> String? {
        let keyCodeMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 50: "`",
            36: "⏎", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋"
        ]
        return keyCodeMap[keyCode]
    }
}
