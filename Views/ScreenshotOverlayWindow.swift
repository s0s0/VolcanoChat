import SwiftUI
import AppKit

// MARK: - Screenshot Overlay Window

/// 全屏覆盖窗口，用于截图区域选择
class ScreenshotOverlayWindow: NSWindow {

    var onRegionSelected: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?

    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // 窗口配置
        self.level = .screenSaver + 1  // 确保在最上层
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // 覆盖所有屏幕
        if let mainScreen = NSScreen.main {
            self.setFrame(mainScreen.frame, display: true)
        }

        // 设置 SwiftUI 内容视图
        let contentView = ScreenshotSelectionView(
            onComplete: { [weak self] rect in
                self?.onRegionSelected?(rect)
            },
            onCancel: { [weak self] in
                self?.onCancelled?()
            }
        )

        self.contentView = NSHostingView(rootView: contentView)

        // 设置键盘事件监听器
        setupKeyboardMonitor()

        print("🪟 [ScreenshotOverlay] 窗口已创建")
    }

    private func setupKeyboardMonitor() {
        // 本地事件监听器（应用激活时）
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {  // 53 是 ESC 键的 keyCode
                print("⌨️ [ScreenshotOverlay] 检测到 ESC 键（本地）")
                self?.onCancelled?()
                return nil  // 吞掉事件，不再传递
            }
            return event
        }

        // 全局事件监听器（即使应用未激活也能接收）
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {  // 53 是 ESC 键的 keyCode
                print("⌨️ [ScreenshotOverlay] 检测到 ESC 键（全局）")
                DispatchQueue.main.async {
                    self?.onCancelled?()
                }
            }
        }

        print("🎧 [ScreenshotOverlay] 键盘监听器已设置（本地 + 全局）")
    }

    deinit {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func show() {
        self.makeKeyAndOrderFront(nil)
        print("👁️ [ScreenshotOverlay] 窗口已显示")
    }

    func hide() {
        self.orderOut(nil)
        print("🙈 [ScreenshotOverlay] 窗口已隐藏")
    }

    // 允许按 ESC 键关闭
    override func cancelOperation(_ sender: Any?) {
        onCancelled?()
    }
}

// MARK: - Screenshot Selection View

/// 截图选择 SwiftUI 视图
struct ScreenshotSelectionView: View {

    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    @State private var isDragging = false

    let onComplete: (CGRect) -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景遮罩（根据选区分成四块，让选区内部完全透明）
                if let start = startPoint, let current = currentPoint {
                    let selectionRect = normalizedRect(from: start, to: current)

                    // 上方遮罩
                    if selectionRect.minY > 0 {
                        Rectangle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: geometry.size.width, height: selectionRect.minY)
                            .position(x: geometry.size.width / 2, y: selectionRect.minY / 2)
                    }

                    // 下方遮罩
                    if selectionRect.maxY < geometry.size.height {
                        Rectangle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: geometry.size.width, height: geometry.size.height - selectionRect.maxY)
                            .position(x: geometry.size.width / 2, y: selectionRect.maxY + (geometry.size.height - selectionRect.maxY) / 2)
                    }

                    // 左侧遮罩
                    if selectionRect.minX > 0 {
                        Rectangle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: selectionRect.minX, height: selectionRect.height)
                            .position(x: selectionRect.minX / 2, y: selectionRect.midY)
                    }

                    // 右侧遮罩
                    if selectionRect.maxX < geometry.size.width {
                        Rectangle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: geometry.size.width - selectionRect.maxX, height: selectionRect.height)
                            .position(x: selectionRect.maxX + (geometry.size.width - selectionRect.maxX) / 2, y: selectionRect.midY)
                    }
                } else {
                    // 没有选区时，显示全屏半透明遮罩
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                }

                // 选择区域边框和装饰
                if let start = startPoint, let current = currentPoint {
                    let selectionRect = normalizedRect(from: start, to: current)

                    // 明亮的边框（多层增强可见性）
                    if selectionRect.width > 0 && selectionRect.height > 0 {
                        Rectangle()
                            .strokeBorder(Color.white, lineWidth: 3)
                            .frame(width: selectionRect.width, height: selectionRect.height)
                            .position(x: selectionRect.midX, y: selectionRect.midY)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 0)
                    }

                    // 内层蓝色边框（只在选区足够大时显示）
                    if selectionRect.width > 10 && selectionRect.height > 10 {
                        Rectangle()
                            .strokeBorder(Color.blue.opacity(0.8), lineWidth: 1)
                            .frame(width: max(1, selectionRect.width - 6), height: max(1, selectionRect.height - 6))
                            .position(x: selectionRect.midX, y: selectionRect.midY)
                    }

                    // 尺寸标签
                    if selectionRect.width > 50 && selectionRect.height > 20 {
                        Text("\(Int(selectionRect.width)) × \(Int(selectionRect.height))")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue)
                            )
                            .foregroundColor(.white)
                            .position(
                                x: selectionRect.midX,
                                y: max(selectionRect.minY - 20, 20)  // 确保不超出屏幕
                            )
                    }

                    // 提示文本（在选区内显示）
                    if selectionRect.width > 150 && selectionRect.height > 50 {
                        VStack(spacing: 4) {
                            Text("松开鼠标确认")
                                .font(.system(size: 11))
                            Text("按 ESC 取消")
                                .font(.system(size: 10))
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.7))
                        )
                        .foregroundColor(.white)
                        .position(
                            x: selectionRect.midX,
                            y: selectionRect.midY
                        )
                    }
                } else {
                    // 初始提示
                    VStack(spacing: 8) {
                        Image(systemName: "viewfinder.rectangular")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.9))

                        Text("拖拽鼠标选择截图区域")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))

                        Text("按 ESC 取消")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.6))
                    )
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
            .contentShape(Rectangle())  // 确保整个区域可以接收鼠标事件
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if startPoint == nil {
                            startPoint = value.startLocation
                            isDragging = true
                        }
                        currentPoint = value.location
                    }
                    .onEnded { value in
                        if let start = startPoint {
                            let rect = normalizedRect(from: start, to: value.location)

                            // 只有当选区足够大时才确认（至少 10x10 像素）
                            if rect.width >= 10 && rect.height >= 10 {
                                onComplete(rect)
                            } else {
                                // 选区太小，重置
                                startPoint = nil
                                currentPoint = nil
                                isDragging = false
                            }
                        }
                    }
            )
            .onAppear {
                // 设置光标为十字
                NSCursor.crosshair.push()
            }
            .onDisappear {
                // 恢复默认光标
                NSCursor.pop()
            }
        }
    }

    /// 根据两个点计算规范化的矩形（确保宽高为正）
    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxX = max(start.x, end.x)
        let maxY = max(start.y, end.y)

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
}

// MARK: - SwiftUI Preview

#Preview {
    ScreenshotSelectionView(
        onComplete: { rect in
            print("Selected rect: \(rect)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
    .frame(width: 800, height: 600)
}
