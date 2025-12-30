import Foundation

struct VolcanoConfig {
    static var accessKeyId: String {
        get { KeychainHelper.shared.load(key: "volcano_access_key_id") ?? "" }
        set { _ = KeychainHelper.shared.save(key: "volcano_access_key_id", value: newValue) }
    }

    static var secretAccessKey: String {
        get { KeychainHelper.shared.load(key: "volcano_secret_access_key") ?? "" }
        set { _ = KeychainHelper.shared.save(key: "volcano_secret_access_key", value: newValue) }
    }

    static var modelName: String {
        get { UserDefaults.standard.string(forKey: "volcano_model_name") ?? "doubao-pro-4k" }
        set { UserDefaults.standard.set(newValue, forKey: "volcano_model_name") }
    }

    static var isConfigured: Bool {
        !accessKeyId.isEmpty && !secretAccessKey.isEmpty
    }
}
