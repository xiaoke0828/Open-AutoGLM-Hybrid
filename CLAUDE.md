# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 提供在此代码库工作的指导。

## 项目概览

Open-AutoGLM 混合方案使 [Open-AutoGLM](https://github.com/zai-org/Open-AutoGLM) 可在 Android 手机上运行，支持两种部署架构：

### 部署方案

**方案 A：纯手机端（Termux）**
- 所有组件运行在手机上
- 无需电脑，完全独立

**方案 B：Mac 服务器（推荐）**
- Mac 运行 Open-AutoGLM 和 AI 服务
- 手机只运行轻量级执行端
- 通过 Tailscale 或局域网连接
- 性能更强，随时随地可用

### 手机控制模式

系统采用双模式自动降级架构：

1. **无障碍服务模式**（主要）：Android 应用提供 HTTP API 用于手机控制
2. **LADB 模式**（备用）：通过本地 ADB 服务器执行 ADB 命令

### 核心架构

**Termux 方案：**
```
用户输入 → Termux (Python + Open-AutoGLM)
         → GRS AI (视觉 + 规划)
         → 手机控制器 (自动降级逻辑)
         → AutoGLM Helper (无障碍服务) 或 LADB
         → 手机执行操作
```

**Mac 服务器方案：**
```
Mac 电脑 → Open-AutoGLM → GRS AI
         → HTTP 请求 (Tailscale/LAN)
         → 手机 AutoGLM Helper
         → 手机执行操作
```

## 项目结构

```
Open-AutoGLM-Hybrid/
├── android-app/                # Android 应用（无障碍服务）
│   ├── app/src/main/java/com/autoglm/helper/
│   │   ├── AutoGLMAccessibilityService.kt  # 核心无障碍服务
│   │   ├── HttpServer.kt                    # HTTP API 服务器（端口 8080）
│   │   └── MainActivity.kt                  # 应用 UI（显示 IP 地址）
│   ├── app/build.gradle.kts                 # 应用级构建配置
│   └── build.gradle.kts                     # 项目级构建配置
│
├── termux-scripts/             # Termux 部署与运行时
│   ├── deploy.sh               # 一键部署脚本
│   └── phone_controller.py     # 带自动降级逻辑的控制器
│
├── mac-server/                 # Mac 服务器部署（新增）
│   ├── deploy-mac.sh           # Mac 部署脚本
│   └── phone_controller_remote.py  # 远程手机控制器
│
├── docs/                       # 文档
│   ├── MAC_SERVER_DEPLOYMENT.md   # Mac 服务器部署指南
│   └── TAILSCALE_GUIDE.md         # Tailscale 远程访问配置
│
└── .github/workflows/          # CI/CD
    └── build-apk.yml           # 推送时自动构建 APK
```

## 常用开发命令

### Android 应用开发

**本地构建 APK：**
```bash
cd android-app
./gradlew assembleDebug        # Debug APK
./gradlew assembleRelease      # Release APK（已优化）
```

**通过 GitHub Actions 构建：**
- 推送到 `main` 分支 → 自动构建 APK
- 下载：Actions → Artifacts → "AutoGLM-Helper-Debug"
- 手动触发：Actions → Build Android APK → Run workflow

**清理构建：**
```bash
cd android-app
./gradlew clean
./gradlew assembleDebug --stacktrace
```

### 测试 Android 应用

Android 应用没有单元测试。测试方式为手动：
1. 在手机上安装 APK
2. 启用无障碍权限
3. 从 Termux 测试 HTTP 端点

### Termux 脚本

**测试部署脚本：**
```bash
cd termux-scripts
bash deploy.sh  # 在 Termux 环境中运行
```

**测试手机控制器：**
```python
# 在 Termux Python 环境中
python phone_controller.py
```

### Mac 服务器部署

**部署服务器：**
```bash
cd mac-server
./deploy-mac.sh
```

**配置服务器：**
```bash
# 编辑配置文件
nano ~/autoglm-server/config.env

# 填入 API Key 和手机 IP
export PHONE_AGENT_API_KEY="your_api_key"
export PHONE_HELPER_URL="http://192.168.1.100:8080"  # 或 Tailscale IP
```

**启动服务器：**
```bash
cd ~/autoglm-server
./start-server.sh
```

**测试远程连接：**
```bash
cd ~/autoglm-server
source venv/bin/activate
source config.env
python phone_controller_remote.py
```

## 关键技术细节

### Android 应用（AutoGLM Helper）

- **语言：** Kotlin
- **最低 SDK：** 24 (Android 7.0)
- **目标 SDK：** 34
- **主要依赖：**
  - NanoHTTPD 2.3.1（轻量级 HTTP 服务器）
  - Kotlin stdlib 1.9.0

**HTTP API 端点（端口 8080）：**
- `POST /tap` - 在坐标 {x, y} 处点击
- `POST /swipe` - 滑动手势 {x1, y1, x2, y2, duration}
- `POST /input` - 输入文本 {text}
- `GET /screenshot` - 返回 Base64 编码的 PNG
- `GET /status` - 服务健康检查

**核心类：**
- `AutoGLMAccessibilityService.kt:18` - 主无障碍服务，管理 HTTP 服务器生命周期
- `HttpServer.kt` - 基于 NanoHTTPD 的 HTTP 服务器，处理 API 请求
- `MainActivity.kt` - 引导用户启用无障碍的简单 UI

### Termux 脚本

**phone_controller.py：**
- 初始化时自动检测可用控制模式
- 降级链：无障碍服务 → LADB → 错误
- 无论底层模式如何，统一 API
- 关键方法：`tap()`、`swipe()`、`input_text()`、`get_screenshot()`

**deploy.sh：**
- 安装 Python 包、Open-AutoGLM 依赖
- 设置环境变量（GRS AI API 密钥）
- 在 PATH 中创建启动脚本

### 通信协议

**无障碍模式：**
```
Termux Python → HTTP (localhost:8080) → AutoGLM Helper → AccessibilityService API → Android 系统
```

**LADB 模式：**
```
Termux Python → ADB 命令 (localhost:5555) → LADB → ADB 协议 → Android 系统
```

## 构建配置

### Gradle 版本
- Gradle: 8.0+（见 `gradle/wrapper/gradle-wrapper.properties`）
- Android Gradle 插件：在 `build.gradle.kts` 中定义
- Kotlin: 1.9.0

### Java 版本
- 源/目标：Java 8
- Kotlin JVM 目标：1.8
- GitHub Actions 使用 JDK 17 进行构建

## 部署

**终端用户：**
1. 从 F-Droid 安装 Termux
2. 安装 AutoGLM Helper APK
3. 为 AutoGLM Helper 启用无障碍权限
4. 在 Termux 中运行 `deploy.sh`
5. 配置 GRS AI API 密钥
6. 运行 `autoglm` 命令

**构建与发布流程：**
1. 推送代码到 GitHub → 自动构建 debug APK
2. 打标签（`git tag v1.0.0 && git push origin v1.0.0`）→ 构建 release APK
3. 从 GitHub Actions artifacts 下载 APK
4. 创建 GitHub Release 并附加 APK

## 重要注意事项

### 安全性
- HTTP 服务器仅监听 localhost (127.0.0.1) - 不暴露到网络
- 不需要身份验证（仅本地通信）
- 所有操作本地执行，无数据上传至外部服务器
- API 密钥本地存储在 Termux 环境中

### Android 版本兼容性
- **Android 7-8：** 基础无障碍 API，无原生截图（降级到 ADB screencap）
- **Android 9+：** 完整无障碍功能，包含 `takeScreenshot()` API
- **Android 11+：** 支持 LADB 无线调试

### 厂商特定问题
- MIUI：需要为 AutoGLM Helper 禁用电池优化
- ColorOS：可能需要禁用权限监控
- EMUI：需要启用特定 ADB 设置

## 架构决策

**为什么选择 Kotlin？**
- Android 官方推荐，简洁，空安全

**为什么选择 NanoHTTPD？**
- 轻量级（<100KB），零依赖，易于集成

**为什么选择 AccessibilityService？**
- 不需要 root，系统级 API，稳定可靠

**为什么 Termux 脚本用 Python？**
- Open-AutoGLM 原生支持，生态丰富，易于修改

**为什么采用降级混合方法？**
- 无障碍服务：90-98% 成功率，重启后存活
- LADB 备份：85-95% 成功率，需要手动启动
- 自动降级最大化可靠性

## 相关文档

- `ARCHITECTURE.md` - 详细技术架构
- `GITHUB_BUILD_GUIDE.md` - CI/CD 设置和故障排除
- `QUICK_START.md` - 部署快速入门
- `docs/DEPLOYMENT_GUIDE.md` - 完整部署指南（带截图）
- `docs/USER_MANUAL.md` - 使用说明
- `android-app/BUILD_INSTRUCTIONS.md` - 本地构建说明
