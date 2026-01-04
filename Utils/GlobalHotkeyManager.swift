import Foundation
import Carbon
import AppKit

class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onHotkeyPressed: (() -> Void)?
    var onHotkeyReleased: (() -> Void)?

    // 默认快捷键：仅 Option 键
    private var isPressed = false
    private var currentKeyCode: UInt16?
    private var currentModifiers: UInt32 = 0x00000800  // optionKey

    private init() {
        loadHotkeySettings()

        // 监听设置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsChanged),
            name: NSNotification.Name("HotkeySettingsChanged"),
            object: nil
        )
    }

    /// 创建独立的快捷键管理器实例（用于截图等其他功能）
    /// - Parameters:
    ///   - keyCode: 按键码（可选，nil 表示仅修饰键）
    ///   - modifiers: 修饰键掩码
    init(keyCode: UInt16? = nil, modifiers: UInt32 = 0) {
        self.currentKeyCode = keyCode
        self.currentModifiers = modifiers
        // 不监听通知，由调用者管理设置变化
    }

    /// 设置快捷键配置
    /// - Parameters:
    ///   - keyCode: 按键码（可选，nil 表示仅修饰键）
    ///   - modifiers: 修饰键掩码
    func setHotkey(keyCode: UInt16?, modifiers: UInt32) {
        self.currentKeyCode = keyCode
        self.currentModifiers = modifiers
    }

    private func loadHotkeySettings() {
        if let keyCode = UserDefaults.standard.object(forKey: "recordingHotkeyCode") as? UInt16 {
            currentKeyCode = keyCode
        }
        currentModifiers = UserDefaults.standard.object(forKey: "recordingHotkeyModifiers") as? UInt32 ?? 0x00000800
    }

    @objc private func hotkeySettingsChanged() {
        print("🔄 [Hotkey] 快捷键设置已更改，重新加载...")
        loadHotkeySettings()
        // 重启事件监听以应用新设置
        stop()
        start()
    }

    func start() {
        // 主动请求辅助功能权限（会弹出系统提示）
        requestAccessibilityPermission()

        // 检查辅助功能权限
        if !checkAccessibilityPermission() {
            print("⚠️ [Hotkey] 需要辅助功能权限")
            print("💡 [Hotkey] 请前往 系统设置 → 隐私与安全性 → 辅助功能")
            showAccessibilityAlert()
            return
        }

        // 创建事件监听（监听 flagsChanged 和 keyDown/keyUp 事件）
        let eventMask = (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ [Hotkey] 创建事件监听失败，可能缺少辅助功能权限")
            showAccessibilityAlert()
            return
        }

        self.eventTap = eventTap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.runLoopSource = runLoopSource

        let hotkeyDesc = describeHotkey()
        print("✅ [Hotkey] 全局快捷键已启动: \(hotkeyDesc)")
    }

    private func describeHotkey() -> String {
        var parts: [String] = []
        if currentModifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if currentModifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if currentModifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if currentModifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if let keyCode = currentKeyCode, let keyName = keyCodeToString(keyCode) {
            parts.append(keyName)
        }
        return parts.isEmpty ? "⌥" : parts.joined(separator: "")
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
            36: "⏎", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋"
        ]
        return keyCodeMap[keyCode]
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil

        print("🛑 [Hotkey] 全局快捷键已停止")
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let eventKeyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // 获取当前按下的修饰键（转换为 Carbon 修饰键掩码）
        var pressedModifiers: UInt32 = 0
        if flags.contains(.maskCommand) { pressedModifiers |= UInt32(cmdKey) }
        if flags.contains(.maskAlternate) { pressedModifiers |= UInt32(optionKey) }
        if flags.contains(.maskControl) { pressedModifiers |= UInt32(controlKey) }
        if flags.contains(.maskShift) { pressedModifiers |= UInt32(shiftKey) }

        // 检查是否匹配自定义快捷键
        let modifiersMatch = (pressedModifiers == currentModifiers)

        if let targetKeyCode = currentKeyCode {
            // 有实际按键：需要修饰键 + 按键都匹配
            if type == .keyDown {
                if modifiersMatch && UInt16(eventKeyCode) == targetKeyCode {
                    if !isPressed {
                        isPressed = true
                        DispatchQueue.main.async {
                            self.onHotkeyPressed?()
                        }
                        print("⌨️ [Hotkey] 快捷键按下: \(describeHotkey())")
                    }
                }
            } else if type == .keyUp {
                if isPressed && UInt16(eventKeyCode) == targetKeyCode {
                    isPressed = false
                    DispatchQueue.main.async {
                        self.onHotkeyReleased?()
                    }
                    print("⌨️ [Hotkey] 快捷键松开: \(describeHotkey())")
                }
            }
        } else {
            // 仅修饰键：只检查修饰键匹配
            if type == .flagsChanged {
                if modifiersMatch && pressedModifiers != 0 {
                    if !isPressed {
                        isPressed = true
                        DispatchQueue.main.async {
                            self.onHotkeyPressed?()
                        }
                        print("⌨️ [Hotkey] 快捷键按下: \(describeHotkey())")
                    }
                } else if isPressed && pressedModifiers != currentModifiers {
                    isPressed = false
                    DispatchQueue.main.async {
                        self.onHotkeyReleased?()
                    }
                    print("⌨️ [Hotkey] 快捷键松开: \(describeHotkey())")
                }
            }
        }

        // 不拦截事件，让系统继续处理
        return Unmanaged.passUnretained(event)
    }

    private func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    private func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "全局快捷键功能需要辅助功能权限才能工作。\n\n请前往：\n系统设置 → 隐私与安全性 → 辅助功能\n\n将 VolcanoChat 添加到列表中。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // 打开系统设置的辅助功能页面
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }
}
