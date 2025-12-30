import Foundation
import AppKit

@MainActor
class GlobalRecordingManager: ObservableObject {
    static let shared = GlobalRecordingManager()

    @Published var isRecording = false

    private let audioRecorder = AudioRecorder()
    private let floatingPanel = RecordingFloatingPanel()
    private let conversationManager = ConversationManager.shared
    private var currentRecordingURL: URL?

    private init() {
        setupHotkey()
    }

    private func setupHotkey() {
        let hotkeyManager = GlobalHotkeyManager.shared

        hotkeyManager.onHotkeyPressed = { [weak self] in
            Task { @MainActor in
                self?.startRecording()
            }
        }

        hotkeyManager.onHotkeyReleased = { [weak self] in
            Task { @MainActor in
                self?.stopRecording()
            }
        }

        hotkeyManager.start()
    }

    private func startRecording() {
        guard !isRecording else { return }

        print("🎤 [Global] 开始全局录音")

        // 先检查麦克风权限
        audioRecorder.requestPermission { [weak self] granted in
            guard let self = self else { return }

            if !granted {
                print("❌ [Global] 麦克风权限被拒绝")
                DispatchQueue.main.async {
                    self.showMicrophoneAlert()
                }
                return
            }

            DispatchQueue.main.async {
                self.isRecording = true

                // 显示浮动窗口
                self.floatingPanel.show()

                // 开始录音
                if let url = self.audioRecorder.startRecording() {
                    self.currentRecordingURL = url
                    print("✅ [Global] 录音已开始，文件: \(url.lastPathComponent)")
                } else {
                    print("❌ [Global] 录音启动失败")
                    self.isRecording = false
                    self.floatingPanel.hide()
                }
            }
        }
    }

    private func stopRecording() {
        guard isRecording else { return }

        print("🎤 [Global] 停止全局录音")
        isRecording = false

        // 隐藏浮动窗口
        floatingPanel.hide()

        // 停止录音并获取URL
        guard let audioURL = audioRecorder.stopRecording() else {
            print("❌ [Global] 录音文件不存在")
            return
        }

        print("📁 [Global] 录音文件路径: \(audioURL.path)")

        // 检查文件大小
        if let fileSize = try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? UInt64 {
            print("📊 [Global] 录音文件大小: \(fileSize) bytes")

            if fileSize < 1000 {
                print("⚠️ [Global] 录音文件过小，可能没有录到声音")
            }
        }

        // 发送录音进行识别
        Task {
            await conversationManager.sendVoiceMessage(audioURL: audioURL)
        }
    }

    private func showMicrophoneAlert() {
        let alert = NSAlert()
        alert.messageText = "需要麦克风权限"
        alert.informativeText = "全局录音功能需要麦克风权限。\n\n请前往：\n系统设置 → 隐私与安全性 → 麦克风\n\n将 VolcanoChat 添加到列表中。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
        }
    }
}
