# Mac 服务器部署指南

## 概述

本指南将帮助您在 Mac 电脑上部署 Open-AutoGLM 服务器，通过网络远程控制 Android 手机。

### 新架构

```
Mac 电脑（服务器端）
    ├─ Open-AutoGLM（任务规划）
    ├─ GRS AI（视觉理解）
    └─ Python 控制脚本
         ↓ HTTP 请求（通过 Tailscale 或局域网）
Android 手机（执行端）
    └─ AutoGLM Helper（无障碍服务）
```

### 优势

- ✅ **Mac 性能强大** - 运行 AI 模型更快
- ✅ **随时随地使用** - 通过 Tailscale 远程控制
- ✅ **手机省电** - 手机只需运行轻量级服务
- ✅ **易于开发** - 在 Mac 上修改代码更方便

## 前提条件

- macOS 10.15+ (推荐 macOS 12+)
- 8GB+ RAM（推荐 16GB+）
- 稳定的网络连接
- GRS AI API Key
- Android 手机（已安装 AutoGLM Helper）

## 部署步骤

### 第 1 步：准备 Android 手机

#### 1.1 安装 AutoGLM Helper

**方式 A：从 GitHub Actions 下载（推荐）**
1. 访问项目的 GitHub Actions 页面
2. 下载最新的 APK artifacts
3. 在手机上安装 APK

**方式 B：本地构建**
```bash
cd android-app
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

#### 1.2 启用无障碍权限

1. 打开 AutoGLM Helper 应用
2. 点击"打开无障碍设置"
3. 找到"AutoGLM Helper"并开启
4. 返回应用，查看状态显示"服务运行中"

#### 1.3 记录手机 IP 地址

在 AutoGLM Helper 应用中，可以看到：
```
服务运行中
端口: 8080
局域网连接: http://192.168.1.100:8080
远程连接: 请使用 Tailscale IP
```

记下这个 IP 地址，稍后会用到。

### 第 2 步：在 Mac 上部署服务器

#### 2.1 下载部署脚本

```bash
# 克隆项目（如果还没有）
git clone https://github.com/your-repo/Open-AutoGLM-Hybrid.git
cd Open-AutoGLM-Hybrid/mac-server

# 或者直接下载部署脚本
curl -O https://raw.githubusercontent.com/your-repo/Open-AutoGLM-Hybrid/main/mac-server/deploy-mac.sh
chmod +x deploy-mac.sh
```

#### 2.2 运行部署脚本

```bash
./deploy-mac.sh
```

脚本会自动：
1. 检查并安装 Homebrew
2. 检查并安装 Python 3
3. 创建虚拟环境
4. 安装 Python 依赖
5. 克隆 Open-AutoGLM 项目
6. 创建配置文件和启动脚本

部署完成后，工作目录位于：`~/autoglm-server/`

### 第 3 步：配置服务器

#### 3.1 编辑配置文件

```bash
nano ~/autoglm-server/config.env
```

修改以下配置：

```bash
# GRS AI API Key（必填）
export PHONE_AGENT_API_KEY="sk-your-actual-api-key-here"

# 手机 AutoGLM Helper 地址
# 局域网示例: http://192.168.1.100:8080
# Tailscale 示例: http://100.64.0.2:8080
export PHONE_HELPER_URL="http://192.168.1.100:8080"

# 日志级别
export LOG_LEVEL="INFO"
```

保存文件：`Ctrl+X`，然后 `Y`，然后 `Enter`

### 第 4 步：配置远程访问（可选但推荐）

如果您需要在不同网络下使用（例如 Mac 在家，手机在外面），需要配置 Tailscale。

详细步骤请参考：[Tailscale 配置指南](TAILSCALE_GUIDE.md)

**快速配置：**

1. 在 Mac 上安装 Tailscale：
```bash
brew install tailscale
sudo tailscale up
```

2. 在手机上安装 Tailscale 应用并登录

3. 查看手机的 Tailscale IP：
```bash
tailscale status
```

4. 更新配置文件中的 IP 为 Tailscale IP：
```bash
export PHONE_HELPER_URL="http://100.64.0.2:8080"
```

### 第 5 步：测试连接

```bash
cd ~/autoglm-server
source config.env

# 测试与手机的连接
curl $PHONE_HELPER_URL/status
```

期望输出：
```json
{
  "status": "ok",
  "service": "AutoGLM Helper",
  "version": "1.0.0",
  "accessibility_enabled": true
}
```

如果连接失败，请参考 [故障排除](#故障排除) 部分。

### 第 6 步：测试手机控制器

```bash
cd ~/autoglm-server
source venv/bin/activate
source config.env

# 运行测试脚本
python phone_controller_remote.py
```

期望输出：
```
测试远程手机控制器...
手机地址: http://192.168.1.100:8080

✅ 成功连接到手机，无障碍服务已启用
测试截图...
✅ 截图成功: (1080, 2400)
   截图已保存: test_screenshot.png

测试点击中心位置...
✅ 点击成功

测试完成！
```

### 第 7 步：启动服务

```bash
cd ~/autoglm-server
./start-server.sh
```

现在您可以开始使用 Open-AutoGLM 了！

## 使用示例

启动服务后，您可以输入任务：

```
请输入任务: 打开淘宝搜索蓝牙耳机

[系统会自动截图、分析、点击、输入等操作]

任务完成！
```

## 日常使用

### 启动服务
```bash
cd ~/autoglm-server
./start-server.sh
```

### 停止服务
按 `Ctrl+C` 停止服务

### 查看日志
日志会实时显示在终端，包含：
- 连接状态
- 任务执行步骤
- 错误信息（如果有）

### 更新代码
```bash
cd ~/autoglm-server/Open-AutoGLM
git pull origin main
```

### 修改配置
```bash
nano ~/autoglm-server/config.env
```

## 故障排除

### 问题 1：无法连接到手机

**错误信息：**
```
无法连接到手机控制服务: http://192.168.1.100:8080
```

**检查清单：**

1. 手机上的 AutoGLM Helper 是否运行？
   - 打开应用，查看状态

2. 手机和 Mac 是否在同一网络？
   - Mac: `ifconfig | grep inet`
   - 手机: 设置 → 关于手机 → 状态 → IP 地址

3. 手机防火墙是否阻止连接？
   - 检查手机安全设置

4. IP 地址是否正确？
   - 在 Mac 上 ping 手机：`ping 192.168.1.100`

**解决方案：**
```bash
# 测试端口连接
nc -zv 192.168.1.100 8080

# 如果无法连接，尝试使用 Tailscale
# 参考 TAILSCALE_GUIDE.md
```

### 问题 2：无障碍权限未启用

**错误信息：**
```
已连接到手机，但无障碍服务未启用
```

**解决方案：**
1. 打开 AutoGLM Helper 应用
2. 点击"打开无障碍设置"
3. 启用 AutoGLM Helper
4. 重启服务

### 问题 3：截图失败

**错误信息：**
```
截图失败: HTTP 500
```

**可能原因：**
- Android 版本低于 11（不支持 takeScreenshot API）
- 无障碍权限不完整

**解决方案：**
1. 确认 Android 版本：设置 → 关于手机 → Android 版本
2. 如果是 Android 7-10，需要使用 LADB 模式（暂不支持）
3. 推荐使用 Android 11+ 设备

### 问题 4：API Key 无效

**错误信息：**
```
API authentication failed
```

**解决方案：**
1. 检查 config.env 中的 API Key 是否正确
2. 确认 API Key 有足够的额度
3. 访问 GRS AI 控制台检查 API Key 状态

### 问题 5：Mac 睡眠后连接断开

**解决方案：**

1. 防止 Mac 睡眠：
```bash
# 临时防止睡眠（运行服务时）
caffeinate -d -i -m -u &
```

2. 或者设置系统偏好：
   - 系统偏好设置 → 节能 → 防止电脑自动进入睡眠

## 性能优化

### 减少延迟

1. **使用有线网络**
   - Mac 和路由器使用网线连接
   - 延迟可降低 50%

2. **优化 Tailscale 连接**
   ```bash
   # 查看连接状态，确保是直连（direct）
   tailscale status
   ```

3. **增加超时时间**
   - 编辑 `phone_controller_remote.py`
   - 修改 `timeout` 参数

### 减少 API 调用成本

1. 使用更小的图片：
   - 在 `phone_controller_remote.py` 中添加图片压缩

2. 缓存重复任务：
   - 记录常见任务的操作序列

## 安全建议

### 网络安全

1. **不要将手机 HTTP 服务暴露到公网**
   - 仅使用局域网或 Tailscale
   - 不要配置端口转发

2. **定期更新密码**
   - Tailscale 账号使用强密码
   - 启用两步验证

### API Key 安全

1. **不要将 API Key 提交到 Git**
   ```bash
   # .gitignore 已包含
   config.env
   ```

2. **定期轮换 API Key**

3. **监控 API 使用情况**

## 高级配置

### 开机自启动

创建 launchd 配置：
```bash
cat > ~/Library/LaunchAgents/com.autoglm.server.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.autoglm.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOUR_USERNAME/autoglm-server/start-server.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# 加载服务
launchctl load ~/Library/LaunchAgents/com.autoglm.server.plist
```

### 多手机支持

编辑配置文件，添加多个手机：
```bash
export PHONE_HELPER_URL_1="http://100.64.0.2:8080"
export PHONE_HELPER_URL_2="http://100.64.0.3:8080"
```

### Web 控制界面（未来功能）

计划支持通过浏览器控制和监控服务。

## 常见问题

### Q: Mac 和手机必须在同一网络吗？
A: 不必须。使用 Tailscale 后，可以在任何网络下使用。

### Q: 可以同时控制多台手机吗？
A: 可以，但需要修改代码支持多实例。

### Q: Mac 睡眠时服务还能运行吗？
A: 不能。需要保持 Mac 唤醒状态或使用服务器。

### Q: 可以用 Windows/Linux 代替 Mac 吗？
A: 可以，部署脚本需要相应调整。

### Q: 性能比 Termux 方案如何？
A: 更快。Mac 的 CPU/内存更强，AI 推理速度明显提升。

## 下一步

- [Tailscale 远程访问配置](TAILSCALE_GUIDE.md)
- [用户手册](USER_MANUAL.md)
- [故障排除](TROUBLESHOOTING.md)
- [架构设计](../ARCHITECTURE.md)

## 反馈与支持

如有问题，请：
1. 查阅本文档的故障排除部分
2. 查看项目 Issues
3. 提交新 Issue 并附上日志

---

**祝您使用愉快！** 🎉
