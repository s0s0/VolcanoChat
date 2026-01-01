import Foundation
import SwiftUI

class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var modelName: String = ""
    @Published var speechAppId: String = ""
    @Published var speechAccessToken: String = ""
    @Published var systemPrompt: String = ""
    @Published var autoPlayResponse: Bool = true
    @Published var enableWebSearch: Bool = false
    @Published var recordingHotkeyCode: UInt16?
    @Published var recordingHotkeyModifiers: UInt32 = 0
    @Published var screenshotHotkeyCode: UInt16?
    @Published var screenshotHotkeyModifiers: UInt32 = 0
    @Published var showingSaveAlert = false

    init() {
        loadSettings()
    }

    func loadSettings() {
        apiKey = KeychainHelper.shared.load(key: "volcano_api_key") ?? ""
        modelName = VolcanoConfig.modelName
        speechAppId = KeychainHelper.shared.load(key: "volcano_speech_appid") ?? ""
        speechAccessToken = KeychainHelper.shared.load(key: "volcano_speech_token") ?? ""
        systemPrompt = UserDefaults.standard.string(forKey: "systemPrompt") ?? ""
        autoPlayResponse = UserDefaults.standard.bool(forKey: "autoPlayResponse")
        enableWebSearch = UserDefaults.standard.bool(forKey: "enableWebSearch")

        // 加载录音快捷键设置（默认值：仅 Option 键，keyCode = nil）
        if let keyCode = UserDefaults.standard.object(forKey: "recordingHotkeyCode") as? UInt16 {
            recordingHotkeyCode = keyCode
        }
        recordingHotkeyModifiers = UserDefaults.standard.object(forKey: "recordingHotkeyModifiers") as? UInt32 ?? 0x00000800  // optionKey = 0x800

        // 加载截图快捷键设置（默认值：⌃A）
        if let keyCode = UserDefaults.standard.object(forKey: "screenshotHotkeyCode") as? UInt16 {
            screenshotHotkeyCode = keyCode
        } else {
            screenshotHotkeyCode = 0  // 'A' key
        }
        screenshotHotkeyModifiers = UserDefaults.standard.object(forKey: "screenshotHotkeyModifiers") as? UInt32 ?? UInt32(NX_CONTROLMASK)  // ⌃
    }

    func saveSettings() {
        // 保存 API Key
        if !apiKey.isEmpty {
            _ = KeychainHelper.shared.save(key: "volcano_api_key", value: apiKey)
        }

        // 保存模型名称
        if !modelName.isEmpty {
            VolcanoConfig.modelName = modelName
        }

        // 保存语音服务 App ID 和 Access Token（TTS 和 ASR 共用）
        if !speechAppId.isEmpty {
            _ = KeychainHelper.shared.save(key: "volcano_speech_appid", value: speechAppId)
        }
        if !speechAccessToken.isEmpty {
            _ = KeychainHelper.shared.save(key: "volcano_speech_token", value: speechAccessToken)
        }

        // 保存 System Prompt
        UserDefaults.standard.set(systemPrompt, forKey: "systemPrompt")

        // 保存录音快捷键设置
        if let keyCode = recordingHotkeyCode {
            UserDefaults.standard.set(keyCode, forKey: "recordingHotkeyCode")
        } else {
            UserDefaults.standard.removeObject(forKey: "recordingHotkeyCode")
        }
        UserDefaults.standard.set(recordingHotkeyModifiers, forKey: "recordingHotkeyModifiers")

        // 保存截图快捷键设置
        if let keyCode = screenshotHotkeyCode {
            UserDefaults.standard.set(keyCode, forKey: "screenshotHotkeyCode")
        } else {
            UserDefaults.standard.removeObject(forKey: "screenshotHotkeyCode")
        }
        UserDefaults.standard.set(screenshotHotkeyModifiers, forKey: "screenshotHotkeyModifiers")

        UserDefaults.standard.set(autoPlayResponse, forKey: "autoPlayResponse")
        UserDefaults.standard.set(enableWebSearch, forKey: "enableWebSearch")

        // 通知全局快捷键管理器重新加载设置
        NotificationCenter.default.post(name: NSNotification.Name("HotkeySettingsChanged"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("ScreenshotHotkeySettingsChanged"), object: nil)

        showingSaveAlert = true
    }
}
