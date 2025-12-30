import SwiftUI
import AppKit

class RecordingFloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
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
        self.orderFront(nil)
        self.animator().alphaValue = 1.0
    }

    func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            self.animator().alphaValue = 0.0
        } completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1.0
        }
    }
}

struct RecordingFloatingView: View {
    @State private var pulseAnimation = false

    var body: some View {
        ZStack {
            // 半透明背景
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

            VStack(spacing: 12) {
                // 麦克风动画图标
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }

                Text("录音中...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(16)
        }
        .frame(width: 200, height: 80)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                pulseAnimation = true
            }
        }
    }
}
