# VolcanoChat 🌋

<div align="center">

**基于火山引擎的 macOS AI 语音助手**

一个功能强大的 macOS 原生应用，集成火山引擎 AI 服务，支持语音对话、全局快捷键录音和截图功能。

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013.0+-blue.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[功能特性](#功能特性) • [安装](#安装) • [配置](#配置) • [使用说明](#使用说明) • [技术栈](#技术栈) • [项目结构](#项目结构)

</div>

---

## 功能特性

### 🤖 AI 对话
- 集成火山引擎方舟平台大语言模型
- 支持流式响应，实时显示 AI 回复
- Markdown 格式渲染，支持代码高亮
- 会话历史管理

### 🎤 语音识别（ASR）
- 实时语音转文字
- 支持高质量音频录制
- 音频电平可视化
- 自动语音端点检测

### 🔊 语音合成（TTS）
- AI 回复自动语音播报（可配置）
- 支持多种音色
- 流畅的语音合成体验

### ⌨️ 全局快捷键
- **录音快捷键**：默认 `⌥ Option`，可自定义
  - 按下开始录音，松开自动转文字并发送给 AI
  - 悬浮窗显示录音状态和音频电平
- **截图快捷键**：默认 `⌘⇧A`，可自定义
  - 拖拽选择截图区域
  - 自动保存到剪贴板
  - 即使应用未激活也能使用

### 📸 智能截图
- 全屏区域选择，清晰的边框指示
- 自动排除应用窗口，截图内容干净
- 支持 Retina 显示器和多显示器
- 快捷键触发，无需切换应用

### 🌐 联网搜索（可选）
- 支持 AI 实时搜索网络信息
- 可在设置中开启/关闭

---

## 安装

### 系统要求
- macOS 13.0 或更高版本
- 火山引擎账号（方舟平台 + 语音服务）

### 下载安装
1. 从 [Releases](https://github.com/s0s0/VolcanoChat/releases) 下载最新版本
2. 解压并拖拽到应用程序文件夹
3. 首次打开需要右键选择"打开"以绕过 Gatekeeper

### 从源码编译
```bash
git clone https://github.com/s0s0/VolcanoChat.git
cd VolcanoChat
open VolcanoChat.xcodeproj
```

在 Xcode 中编译并运行（⌘R）

---

## 配置

### 1. 火山引擎方舟平台配置

访问 [火山引擎方舟平台](https://console.volcengine.com/ark)

1. 创建应用并获取 **API Key**
2. 创建推理接入点并获取 **Endpoint ID**（通常以 `ep-` 开头）

### 2. 语音服务配置

访问 [火山引擎语音技术控制台](https://console.volcengine.com/speech)

1. 创建项目并获取 **App ID**
2. 生成 **Access Token**

### 3. 应用内配置

打开应用后，按 `⌘,` 进入设置页面：

#### 方舟平台配置
- **API Key**: 粘贴方舟平台的 API Key
- **模型/Endpoint ID**: 粘贴 Endpoint ID（如 `ep-xxxxx`）

#### 语音服务配置
- **语音服务 App ID**: 粘贴语音技术的 App ID
- **语音服务 Access Token**: 粘贴 Access Token

#### 功能设置
- **录音快捷键**: 点击输入框，按下你想设置的快捷键组合
- **截图快捷键**: 点击输入框，按下你想设置的快捷键组合
- **自动语音播报**: 开启后 AI 回复会自动转语音播放
- **启用联网搜索**: 允许 AI 搜索实时信息

#### 系统提示词（可选）
自定义 AI 的角色和行为，例如：
```
你是一个专业的编程助手，擅长 Swift 和 macOS 开发。
```

### 4. 授权权限

首次使用时，应用会请求以下权限：

- **麦克风权限**: 用于语音录制
- **辅助功能权限**: 用于全局快捷键监听
- **屏幕录制权限**: 用于截图功能

请在系统设置中授予这些权限。

---

## 使用说明

### 语音对话
1. 按下录音快捷键（默认 `⌥ Option`）
2. 对着麦克风说话
3. 松开快捷键，自动识别并发送给 AI
4. AI 回复会显示在对话窗口，并可选择语音播报

### 文字对话
1. 在底部输入框输入消息
2. 按 `Enter` 或点击发送按钮
3. AI 回复支持 Markdown 格式

### 截图功能
1. 按下截图快捷键（默认 `⌘⇧A`）
2. 拖拽鼠标选择截图区域
3. 松开鼠标确认，或按 `ESC` 取消
4. 截图自动保存到剪贴板

---

## 技术栈

### 核心框架
- **SwiftUI** - 现代化 UI 框架
- **AppKit** - macOS 原生控件
- **Combine** - 响应式编程

### 系统框架
- **ScreenCaptureKit** - 屏幕截图（macOS 13+）
- **AVFoundation** - 音频录制和播放
- **Carbon** - 全局键盘事件监听

### 火山引擎集成
- 方舟平台 LLM API
- 语音识别 (ASR) API
- 语音合成 (TTS) API

### 架构模式
- **MVVM** - Model-View-ViewModel 架构
- **依赖注入** - 服务层解耦
- **Protocol-Oriented** - 面向协议编程

---

## 项目结构

```
VolcanoChat/
├── App/                          # 应用入口
│   └── VolcanoChatbotApp.swift  # 主应用文件
│
├── Models/                       # 数据模型
│   ├── Message.swift            # 消息模型
│   ├── Conversation.swift       # 会话模型
│   ├── AudioRecorder.swift      # 音频录制器
│   └── AudioPlayer.swift        # 音频播放器
│
├── ViewModels/                   # 视图模型
│   ├── ChatViewModel.swift              # 聊天视图模型
│   ├── SettingsViewModel.swift          # 设置视图模型
│   ├── GlobalRecordingManager.swift     # 全局录音管理器
│   └── GlobalScreenshotManager.swift    # 全局截图管理器
│
├── Views/                        # 视图
│   ├── ContentView.swift                # 主视图
│   ├── ChatView.swift                   # 聊天视图
│   ├── MessageRow.swift                 # 消息行
│   ├── InputBar.swift                   # 输入框
│   ├── SettingsView.swift               # 设置页面
│   ├── HotkeyRecorderView.swift         # 快捷键录制器
│   ├── RecordingFloatingPanel.swift     # 录音悬浮窗
│   ├── ScreenshotOverlayWindow.swift    # 截图选择窗口
│   ├── MarkdownText.swift               # Markdown 渲染
│   └── APITestView.swift                # API 测试视图
│
├── Services/                     # 服务层
│   ├── VolcanoLLMService.swift          # 大语言模型服务
│   ├── VolcanoASRService.swift          # 语音识别服务
│   ├── VolcanoTTSService.swift          # 语音合成服务
│   └── ConversationManager.swift        # 会话管理服务
│
└── Utils/                        # 工具类
    ├── NetworkManager.swift             # 网络请求管理
    ├── VolcanoSigner.swift              # API 签名工具
    ├── VolcanoConfig.swift              # 配置管理
    ├── GlobalHotkeyManager.swift        # 全局快捷键管理
    ├── ScreenshotCapture.swift          # 截图捕获
    ├── ScreenRecordingPermissionHelper.swift  # 屏幕录制权限
    ├── ClipboardHelper.swift            # 剪贴板工具
    └── KeychainHelper.swift             # 钥匙串存储
```

---

## 开发信息

### 代码统计
- **总代码行数**: 3,603 行
- **Swift 文件数**: 31 个
- **架构**: MVVM

### 代码分布
| 模块 | 行数 | 占比 |
|------|------|------|
| Views | 1,210 行 | 33.6% |
| Utils | 832 行 | 23.1% |
| Services | 712 行 | 19.8% |
| ViewModels | 514 行 | 14.3% |
| Models | 285 行 | 7.9% |
| App | 50 行 | 1.4% |

### 构建要求
- Xcode 15.0+
- Swift 5.9+
- macOS 13.0+ Deployment Target

---

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 致谢

- [火山引擎](https://www.volcengine.com/) - 提供 AI 服务支持
- [Apple](https://www.apple.com/) - 提供 macOS 开发框架

---

## 联系方式

如有问题或建议，欢迎：
- 提交 [Issue](https://github.com/s0s0/VolcanoChat/issues)
- 发起 [Pull Request](https://github.com/s0s0/VolcanoChat/pulls)

---

<div align="center">

**Made with ❤️ using Swift and SwiftUI**

🤖 Generated with [Claude Code](https://claude.com/claude-code)

</div>
