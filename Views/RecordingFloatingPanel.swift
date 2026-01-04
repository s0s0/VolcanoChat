import SwiftUI
import AppKit

class RecordingFloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // 设置内容视图
        self.contentView = NSHostingView(rootView: RecordingFloatingView())

        // 定位到屏幕右上角
        positionAtTopRight()
    }

    func positionAtTopRight() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let x = screenFrame.maxX - frame.width - 20
        let y = screenFrame.maxY - frame.height - 20

        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func show() {
        positionAtTopRight()

        // 初始缩放动画
        self.alphaValue = 0.0
        self.setFrame(NSRect(
            x: frame.origin.x + frame.width / 4,
            y: frame.origin.y + frame.height / 4,
            width: frame.width / 2,
            height: frame.height / 2
        ), display: true)

        self.orderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)

            self.animator().alphaValue = 1.0
            self.animator().setFrame(NSRect(
                x: frame.origin.x - frame.width / 4,
                y: frame.origin.y - frame.height / 4,
                width: 100,
                height: 100
            ), display: true)
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            self.animator().alphaValue = 0.0
            self.animator().setFrame(NSRect(
                x: frame.origin.x + 12,
                y: frame.origin.y + 12,
                width: frame.width - 24,
                height: frame.height - 24
            ), display: true)
        } completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1.0
            // 恢复原始大小
            self.setFrame(NSRect(
                x: self.frame.origin.x - 12,
                y: self.frame.origin.y - 12,
                width: 100,
                height: 100
            ), display: false)
        }
    }
}

struct RecordingFloatingView: View {
    @State private var pulseAnimation1 = false
    @State private var pulseAnimation2 = false
    @State private var pulseAnimation3 = false
    @State private var scaleAnimation = false
    @State private var waveAmplitudes: [CGFloat] = [0.3, 0.5, 0.7, 0.5, 0.3, 0.5, 0.8, 0.4]

    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // 主容器背景
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            VStack(spacing: 10) {
                // 麦克风图标 + 脉冲动画
                ZStack {
                    // 外层脉冲波 1
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 46, height: 46)
                        .scaleEffect(pulseAnimation1 ? 1.4 : 1.0)
                        .opacity(pulseAnimation1 ? 0 : 1)

                    // 中层脉冲波 2
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.red.opacity(0.4), Color.red.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 46, height: 46)
                        .scaleEffect(pulseAnimation2 ? 1.3 : 1.0)
                        .opacity(pulseAnimation2 ? 0 : 1)

                    // 内层脉冲波 3
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.red.opacity(0.5), Color.red.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 46, height: 46)
                        .scaleEffect(pulseAnimation3 ? 1.2 : 1.0)
                        .opacity(pulseAnimation3 ? 0 : 1)

                    // 主圆形背景
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.8), Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .scaleEffect(scaleAnimation ? 1.05 : 1.0)
                        .shadow(color: .red.opacity(0.4), radius: 6, x: 0, y: 3)

                    // 麦克风图标
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .scaleEffect(scaleAnimation ? 1.05 : 1.0)
                }
                .frame(height: 52)

                // 音量波形指示器
                HStack(spacing: 2) {
                    ForEach(0..<8, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(
                                LinearGradient(
                                    colors: [.red.opacity(0.8), .red],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 2.5, height: 3 + waveAmplitudes[index] * 10)
                            .animation(
                                .easeInOut(duration: 0.15),
                                value: waveAmplitudes[index]
                            )
                    }
                }
                .frame(height: 14)
                .onReceive(timer) { _ in
                    updateWaveform()
                }
            }
            .padding(12)
        }
        .frame(width: 100, height: 100)
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // 脉冲动画 1
        withAnimation(
            Animation.easeOut(duration: 1.5)
                .repeatForever(autoreverses: false)
        ) {
            pulseAnimation1 = true
        }

        // 脉冲动画 2 - 延迟 0.3 秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(
                Animation.easeOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
            ) {
                pulseAnimation2 = true
            }
        }

        // 脉冲动画 3 - 延迟 0.6 秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(
                Animation.easeOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
            ) {
                pulseAnimation3 = true
            }
        }

        // 主图标缩放动画
        withAnimation(
            Animation.easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
        ) {
            scaleAnimation = true
        }
    }

    private func updateWaveform() {
        // 随机更新波形振幅，模拟音量变化
        for i in 0..<waveAmplitudes.count {
            waveAmplitudes[i] = CGFloat.random(in: 0.2...1.0)
        }
    }
}
