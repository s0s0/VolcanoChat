import AVFoundation
import Foundation

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingLevel: Float = 0.0

    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var levelTimer: Timer?

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
        #else
        // macOS: 列出所有可用的音频输入设备
        print("🎤 [Recorder] 检查音频输入设备...")

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        let devices = discoverySession.devices
        print("🎤 [Recorder] 找到 \(devices.count) 个音频设备:")
        for device in devices {
            print("  - \(device.localizedName)")
        }

        // 检查默认麦克风
        if let defaultDevice = AVCaptureDevice.default(for: .audio) {
            print("✅ [Recorder] 默认麦克风: \(defaultDevice.localizedName)")
        } else {
            print("⚠️ [Recorder] 未找到默认麦克风")
        }
        #endif
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        #if os(iOS)
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
        #else
        // macOS: 请求麦克风权限
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            print("🎤 [Recorder] 麦克风权限: \(granted ? "已授予" : "被拒绝")")
            DispatchQueue.main.async {
                completion(granted)
            }
        }
        #endif
    }

    func startRecording() -> URL? {
        #if os(macOS)
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording_\(Date().timeIntervalSince1970).wav")
        // macOS: 使用 WAV 格式 (PCM)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        #else
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 32000
        ]
        #endif

        print("🎤 [Recorder] 开始录音到文件: \(audioFilename.lastPathComponent)")
        print("🎤 [Recorder] 音频设置: \(settings)")

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true

            // 准备录音
            guard audioRecorder?.prepareToRecord() == true else {
                print("❌ [Recorder] 准备录音失败")
                return nil
            }

            print("🎤 [Recorder] 准备录音成功，当前录音器状态:")
            print("  - isRecording: \(audioRecorder?.isRecording ?? false)")
            print("  - url: \(audioFilename.path)")

            // 开始录音
            guard audioRecorder?.record() == true else {
                print("❌ [Recorder] 开始录音失败")
                return nil
            }

            isRecording = true
            print("✅ [Recorder] 录音已启动")
            print("  - isRecording: \(audioRecorder?.isRecording ?? false)")

            // Start level monitoring
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateMeters()
            }

            return audioFilename
        } catch {
            print("❌ [Recorder] 无法启动录音: \(error.localizedDescription)")
            print("  - 详细错误: \(error)")
            return nil
        }
    }

    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        let recordingURL = audioRecorder?.url

        audioRecorder?.stop()
        isRecording = false
        recordingLevel = 0.0

        levelTimer?.invalidate()
        levelTimer = nil

        // 清理音频录制器，释放资源
        audioRecorder = nil

        return recordingURL
    }

    private func updateMeters() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)
        let normalizedLevel = pow(10, power / 20) // Convert dB to linear

        // 每秒打印一次音频电平用于调试
        if Int(Date().timeIntervalSince1970) % 10 == 0 {
            print("🔊 [Recorder] 音频电平 - 平均: \(power) dB, 峰值: \(peakPower) dB")
        }

        DispatchQueue.main.async {
            self.recordingLevel = normalizedLevel
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("📊 [Recorder] 录音完成: \(flag ? "成功" : "失败")")
        print("📁 [Recorder] 文件路径: \(recorder.url.path)")

        if let fileSize = try? FileManager.default.attributesOfItem(atPath: recorder.url.path)[.size] as? UInt64 {
            print("📊 [Recorder] 文件大小: \(fileSize) bytes")
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ [Recorder] 编码错误: \(error?.localizedDescription ?? "未知错误")")
    }
}
