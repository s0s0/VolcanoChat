import SwiftUI
import AppKit

// MARK: - Drawing Path

/// 涂鸦路径
struct DrawingPath: Identifiable {
    let id = UUID()
    var points: [CGPoint] = []
}

/// 截图结果（包含区域和涂鸦）
struct ScreenshotResult {
    let rect: CGRect
    let drawings: [DrawingPath]
}

// MARK: - Screenshot Overlay Window

/// 全屏覆盖窗口，用于截图区域选择
class ScreenshotOverlayWindow: NSWindow {

    var onRegionSelected: ((ScreenshotResult) -> Void)?
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
            onComplete: { [weak self] result in
                self?.onRegionSelected?(result)
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
    @State private var isSelectionComplete = false  // 选区完成状态
    @State private var finalRect: CGRect?  // 最终选定的区域

    // 涂鸦相关状态
    @State private var drawingPaths: [DrawingPath] = []  // 所有涂鸦路径
    @State private var currentDrawingPath: DrawingPath?  // 当前正在绘制的路径
    @State private var isDrawing = false  // 是否正在涂鸦

    let onComplete: (ScreenshotResult) -> Void
    let onCancel: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景遮罩（根据选区分成四块，让选区内部完全透明）
                if let rect = displayRect {
                    // 上方遮罩
                    if rect.minY > 0 {
                        Rectangle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: geometry.size.width, height: rect.minY)
                            .position(x: geometry.size.width / 2, y: rect.minY / 2)
                    }

                    // 下方遮罩
                    if rect.maxY < geometry.size.height {
                        Rectangle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: geometry.size.width, height: geometry.size.height - rect.maxY)
                            .position(x: geometry.size.width / 2, y: rect.maxY + (geometry.size.height - rect.maxY) / 2)
                    }

                    // 左侧遮罩
                    if rect.minX > 0 {
                        Rectangle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: rect.minX, height: rect.height)
                            .position(x: rect.minX / 2, y: rect.midY)
                    }

                    // 右侧遮罩
                    if rect.maxX < geometry.size.width {
                        Rectangle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: geometry.size.width - rect.maxX, height: rect.height)
                            .position(x: rect.maxX + (geometry.size.width - rect.maxX) / 2, y: rect.midY)
                    }
                } else {
                    // 没有选区时，显示全屏半透明遮罩
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                }

                // 选择区域边框和装饰
                if let rect = displayRect {
                    // 明亮的边框（多层增强可见性）
                    if rect.width > 0 && rect.height > 0 {
                        Rectangle()
                            .strokeBorder(Color.white, lineWidth: 3)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 0)
                    }

                    // 内层蓝色边框（只在选区足够大时显示）
                    if rect.width > 10 && rect.height > 10 {
                        Rectangle()
                            .strokeBorder(Color.blue.opacity(0.8), lineWidth: 1)
                            .frame(width: max(1, rect.width - 6), height: max(1, rect.height - 6))
                            .position(x: rect.midX, y: rect.midY)
                    }

                    // 尺寸标签
                    if rect.width > 50 && rect.height > 20 {
                        Text("\(Int(rect.width)) × \(Int(rect.height))")
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue)
                            )
                            .foregroundColor(.white)
                            .position(
                                x: rect.midX,
                                y: max(rect.minY - 20, 20)  // 确保不超出屏幕
                            )
                    }

                    // 涂鸦路径渲染（只在选区内显示）
                    if isSelectionComplete {
                        // 剪裁到选区内并转换坐标
                        Canvas { context, size in
                            // 渲染所有完成的涂鸦路径
                            for path in drawingPaths {
                                guard !path.points.isEmpty else { continue }

                                var canvasPath = Path()
                                // 转换为相对于选区的坐标
                                let firstPoint = CGPoint(
                                    x: path.points[0].x - rect.minX,
                                    y: path.points[0].y - rect.minY
                                )
                                canvasPath.move(to: firstPoint)

                                for point in path.points.dropFirst() {
                                    let relativePoint = CGPoint(
                                        x: point.x - rect.minX,
                                        y: point.y - rect.minY
                                    )
                                    canvasPath.addLine(to: relativePoint)
                                }

                                context.stroke(
                                    canvasPath,
                                    with: .color(.red),
                                    lineWidth: 3
                                )
                            }

                            // 渲染当前正在绘制的路径
                            if let currentPath = currentDrawingPath, !currentPath.points.isEmpty {
                                var canvasPath = Path()
                                let firstPoint = CGPoint(
                                    x: currentPath.points[0].x - rect.minX,
                                    y: currentPath.points[0].y - rect.minY
                                )
                                canvasPath.move(to: firstPoint)

                                for point in currentPath.points.dropFirst() {
                                    let relativePoint = CGPoint(
                                        x: point.x - rect.minX,
                                        y: point.y - rect.minY
                                    )
                                    canvasPath.addLine(to: relativePoint)
                                }

                                context.stroke(
                                    canvasPath,
                                    with: .color(.red),
                                    lineWidth: 3
                                )
                            }
                        }
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)  // 不拦截鼠标事件
                    }

                    // 选区完成后显示确认/取消按钮
                    if isSelectionComplete {
                        HStack(spacing: 12) {
                            // 取消按钮
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    resetSelection()
                                }
                            }) {
                                Text("取消")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.red.opacity(0.8))
                                    )
                            }
                            .buttonStyle(.plain)

                            // 确定按钮
                            Button(action: {
                                if let finalRect = finalRect {
                                    let result = ScreenshotResult(
                                        rect: finalRect,
                                        drawings: drawingPaths
                                    )
                                    onComplete(result)
                                }
                            }) {
                                Text("确定")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.green.opacity(0.8))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.7))
                        )
                        .position(
                            x: rect.midX,
                            y: min(rect.maxY + 40, geometry.size.height - 30)  // 在选区下方，不超出屏幕
                        )
                        .transition(.scale.combined(with: .opacity))
                    } else if isDragging {
                        // 拖拽时的提示文本
                        if rect.width > 150 && rect.height > 50 {
                            VStack(spacing: 4) {
                                Text("松开鼠标继续")
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
                                x: rect.midX,
                                y: rect.midY
                            )
                        }
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
                        // 如果已经完成选择，处理涂鸦
                        if isSelectionComplete {
                            // 检查是否在选区内
                            if let rect = finalRect, rect.contains(value.location) {
                                if !isDrawing {
                                    // 开始新的涂鸦路径
                                    isDrawing = true
                                    currentDrawingPath = DrawingPath(points: [value.location])
                                } else {
                                    // 继续当前涂鸦路径
                                    currentDrawingPath?.points.append(value.location)
                                }
                            }
                            return
                        }

                        // 原有的选区拖拽逻辑
                        if startPoint == nil {
                            startPoint = value.startLocation
                            isDragging = true
                        }
                        currentPoint = value.location
                    }
                    .onEnded { value in
                        // 如果正在涂鸦，结束涂鸦路径
                        if isDrawing {
                            if let path = currentDrawingPath {
                                drawingPaths.append(path)
                            }
                            currentDrawingPath = nil
                            isDrawing = false
                            return
                        }

                        // 如果已经完成选择，不响应拖拽
                        guard !isSelectionComplete else { return }

                        if let start = startPoint {
                            let rect = normalizedRect(from: start, to: value.location)

                            // 只有当选区足够大时才显示确认按钮（至少 10x10 像素）
                            if rect.width >= 10 && rect.height >= 10 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    finalRect = rect
                                    isSelectionComplete = true
                                    isDragging = false
                                }
                            } else {
                                // 选区太小，重置
                                resetSelection()
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

    /// 当前显示的矩形（拖拽中或已完成）
    private var displayRect: CGRect? {
        if let finalRect = finalRect {
            return finalRect
        } else if let start = startPoint, let current = currentPoint {
            return normalizedRect(from: start, to: current)
        }
        return nil
    }

    /// 重置选择状态
    private func resetSelection() {
        startPoint = nil
        currentPoint = nil
        isDragging = false
        isSelectionComplete = false
        finalRect = nil
        drawingPaths = []
        currentDrawingPath = nil
        isDrawing = false
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
        onComplete: { result in
            print("Selected rect: \(result.rect)")
            print("Drawings count: \(result.drawings.count)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
    .frame(width: 800, height: 600)
}
