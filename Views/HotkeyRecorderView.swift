import SwiftUI
import Carbon

struct HotkeyRecorderView: View {
    @Binding var keyCode: UInt16?
    @Binding var modifiers: UInt32
    @State private var isRecording = false
    @State private var displayText: String = ""

    var body: some View {
        HStack {
            Text(displayText.isEmpty ? "点击录制快捷键" : displayText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.blue : Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onTapGesture {
                    startRecording()
                }

            if !displayText.isEmpty {
                Button(action: clearHotkey) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            updateDisplayText()
        }
    }

    private func startRecording() {
        isRecording = true
        displayText = "按下快捷键..."

        // 创建本地事件监听器
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if self.isRecording {
                self.handleKeyEvent(event)
                return nil  // 拦截事件
            }
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            // 按下了实际的按键
            keyCode = event.keyCode
            modifiers = event.modifierFlags.carbonModifiers
            isRecording = false
            updateDisplayText()
        } else if event.type == .flagsChanged {
            // 只按下修饰键
            let newModifiers = event.modifierFlags.carbonModifiers
            if newModifiers != 0 {
                keyCode = nil
                modifiers = newModifiers
                isRecording = false
                updateDisplayText()
            }
        }
    }

    private func updateDisplayText() {
        var parts: [String] = []

        // 修饰键
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }
        if modifiers & UInt32(controlKey) != 0 {
            parts.append("⌃")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }

        // 实际按键
        if let keyCode = keyCode {
            if let keyName = keyCodeToString(keyCode) {
                parts.append(keyName)
            }
        }

        displayText = parts.isEmpty ? "" : parts.joined(separator: "")
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
