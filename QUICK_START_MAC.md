# Mac 服务器快速开始

这是 Open-AutoGLM Mac 服务器方案的 5 分钟快速开始指南。

## 前提条件

- ✅ macOS 10.15+
- ✅ 8GB+ RAM
- ✅ Android 手机（Android 11+ 推荐）
- ✅ GRS AI API Key

## 步骤 1：准备手机（2 分钟）

### 1.1 安装 AutoGLM Helper

从 GitHub Actions 下载最新 APK：
```bash
# 在浏览器中访问
https://github.com/your-repo/Open-AutoGLM-Hybrid/actions
```

或本地构建：
```bash
cd android-app
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

### 1.2 启用无障碍权限

1. 打开手机上的 **AutoGLM Helper** 应用
2. 点击 **"打开无障碍设置"**
3. 找到 **"AutoGLM Helper"** 并开启
4. 返回应用，确认状态显示 **"服务运行中"**

### 1.3 记录手机 IP

在应用中会显示：
```
局域网连接: http://192.168.1.100:8080
```

记下这个 IP 地址（例如：`192.168.1.100`）

## 步骤 2：部署 Mac 服务器（3 分钟）

### 2.1 运行部署脚本

```bash
# 下载并运行
cd /path/to/Open-AutoGLM-Hybrid/mac-server
./deploy-mac.sh
```

脚本会自动安装所有依赖，完成后会在 `~/autoglm-server/` 创建工作目录。

### 2.2 配置 API Key 和手机 IP

```bash
nano ~/autoglm-server/config.env
```

修改以下内容：
```bash
# 填入您的 GRS AI API Key
export PHONE_AGENT_API_KEY="sk-your-actual-api-key-here"

# 填入手机的 IP 地址（步骤 1.3 中记录的）
export PHONE_HELPER_URL="http://192.168.1.100:8080"
```

保存：`Ctrl+X`，然后 `Y`，然后 `Enter`

### 2.3 测试连接

```bash
cd ~/autoglm-server
source config.env
curl $PHONE_HELPER_URL/status
```

应该看到：
```json
{
  "status": "ok",
  "service": "AutoGLM Helper",
  "version": "1.0.0",
  "accessibility_enabled": true
}
```

## 步骤 3：启动服务（1 分钟）

```bash
cd ~/autoglm-server
./start-server.sh
```

看到提示后，输入任务：
```
请输入任务: 打开淘宝搜索蓝牙耳机
```

手机会自动执行操作！🎉

## 下一步

### 配置远程访问（可选）

如果您想在不同网络下使用，配置 Tailscale：

```bash
# 在 Mac 上
brew install tailscale
sudo tailscale up

# 在手机上
# 安装 Tailscale 应用并登录

# 更新配置使用 Tailscale IP
nano ~/autoglm-server/config.env
# export PHONE_HELPER_URL="http://100.64.0.2:8080"
```

详细步骤：[Tailscale 配置指南](docs/TAILSCALE_GUIDE.md)

## 故障排除

### 无法连接到手机

```bash
# 检查手机和 Mac 是否在同一网络
# Mac IP
ifconfig | grep inet

# 测试连接
ping 192.168.1.100
curl http://192.168.1.100:8080/status
```

### API Key 错误

确认 config.env 中的 API Key 正确且有额度。

### 手机无障碍权限未启用

重新打开 AutoGLM Helper 应用，确认状态为"服务运行中"。

## 完整文档

- [Mac 服务器详细部署指南](docs/MAC_SERVER_DEPLOYMENT.md)
- [Tailscale 远程访问配置](docs/TAILSCALE_GUIDE.md)
- [架构设计文档](ARCHITECTURE.md)
- [Android 应用构建说明](android-app/BUILD_INSTRUCTIONS.md)

## 支持

遇到问题？
1. 查阅文档的故障排除部分
2. 查看项目 Issues
3. 提交新 Issue 并附上日志

---

**开始使用 Open-AutoGLM 吧！** 🚀
