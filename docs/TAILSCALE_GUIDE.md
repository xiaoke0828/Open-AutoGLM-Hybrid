# Tailscale 远程访问配置指南

## 简介

Tailscale 是最简单的远程访问方案，可以让您的 Mac 和手机在不同网络下也能像在同一局域网一样通信。

### 优势

- ✅ **零配置** - 无需公网 IP 或端口转发
- ✅ **安全** - 端到端加密，自动密钥轮换
- ✅ **快速** - P2P 直连，延迟极低
- ✅ **免费** - 个人使用免费，最多 100 台设备
- ✅ **跨平台** - 支持 macOS、iOS、Android、Windows、Linux

## 安装配置

### 第 1 步：在 Mac 上安装 Tailscale

**方式 A：使用 Homebrew（推荐）**
```bash
brew install tailscale
```

**方式 B：从官网下载**
1. 访问 https://tailscale.com/download/mac
2. 下载 DMG 安装包
3. 安装并启动

### 第 2 步：在 Mac 上登录 Tailscale

```bash
# 启动 Tailscale
sudo tailscaled install-system-daemon
tailscale up

# 会打开浏览器，登录您的账号（Google/Microsoft/GitHub）
```

登录后，Mac 会获得一个 Tailscale IP 地址（100.x.x.x）。

**查看 Mac 的 Tailscale IP：**
```bash
tailscale ip -4
```

输出示例：`100.64.0.1`

### 第 3 步：在手机上安装 Tailscale

**Android：**
1. 打开 Google Play Store
2. 搜索 "Tailscale"
3. 安装并打开应用
4. 使用相同的账号登录
5. 点击连接按钮

**注意：** 如果 Play Store 不可用，可以从 F-Droid 或 Tailscale 官网下载 APK。

### 第 4 步：获取手机的 Tailscale IP

在手机上打开 Tailscale 应用，会显示设备的 IP 地址，例如：`100.64.0.2`

或者在 Mac 上查看所有设备：
```bash
tailscale status
```

输出示例：
```
100.64.0.1   your-mac          user@   macOS   -
100.64.0.2   your-phone        user@   android -
```

## 配置 Open-AutoGLM 使用 Tailscale

### 第 5 步：更新配置文件

编辑 Mac 服务器的配置文件：
```bash
nano ~/autoglm-server/config.env
```

修改 `PHONE_HELPER_URL` 为手机的 Tailscale IP：
```bash
# 将 your-phone-tailscale-ip 替换为实际 IP
export PHONE_HELPER_URL="http://100.64.0.2:8080"
```

保存文件（Ctrl+X，然后 Y，然后 Enter）。

### 第 6 步：测试连接

```bash
cd ~/autoglm-server
source config.env

# 测试与手机的连接
curl $PHONE_HELPER_URL/status
```

如果返回类似以下 JSON，说明连接成功：
```json
{
  "status": "ok",
  "service": "AutoGLM Helper",
  "version": "1.0.0",
  "accessibility_enabled": true
}
```

### 第 7 步：启动服务

```bash
cd ~/autoglm-server
./start-server.sh
```

现在，无论您的 Mac 和手机在哪个网络，都可以正常工作了！

## 高级配置

### 设置设备名称

为了方便识别，可以给设备设置友好的名称：

**Mac：**
```bash
sudo tailscale set --hostname=my-mac
```

**手机：**
在 Tailscale 应用的设置中修改设备名称。

### 启用 MagicDNS

MagicDNS 允许您使用设备名称而不是 IP 地址访问：

1. 访问 Tailscale 管理界面：https://login.tailscale.com/admin/dns
2. 启用 "MagicDNS"

然后您可以使用设备名称：
```bash
export PHONE_HELPER_URL="http://your-phone:8080"
```

### 防火墙规则（可选）

如果需要限制访问，可以在 Tailscale 管理界面配置 ACL（Access Control List）。

## 故障排除

### 问题 1：无法连接到手机

**检查清单：**
```bash
# 1. 检查 Tailscale 是否运行
tailscale status

# 2. 检查手机是否在线
tailscale ping your-phone-ip

# 3. 检查手机上的 AutoGLM Helper 是否运行
# 打开手机上的 AutoGLM Helper 应用，查看状态

# 4. 测试端口连接
nc -zv your-phone-ip 8080
```

### 问题 2：连接很慢

**原因：** 可能无法建立 P2P 直连，流量经过 Tailscale 中继服务器。

**解决：**
```bash
# 查看连接状态
tailscale status

# 如果显示 "relay", 说明是中继连接
# 尝试重启 Tailscale
tailscale down
tailscale up
```

### 问题 3：Mac 重启后 Tailscale 未自动启动

```bash
# 设置开机自启动
sudo tailscale up --accept-routes
```

### 问题 4：手机省电模式导致断连

**Android：**
1. 设置 → 应用 → Tailscale
2. 电池 → 不限制（或允许后台运行）
3. 网络 → 允许后台使用数据

## 常见问题

### Q: Tailscale 安全吗？
A: 非常安全。Tailscale 使用 WireGuard 协议，端到端加密，即使 Tailscale 公司也无法看到您的数据。

### Q: Tailscale 会消耗很多流量吗？
A: 不会。Tailscale 只是建立 P2P 连接，实际数据传输是设备之间直连，不经过第三方服务器（除非无法直连时使用中继）。

### Q: 免费版有限制吗？
A: 免费版支持最多 100 台设备，3 个用户，对个人使用完全够用。

### Q: 可以同时使用局域网和 Tailscale 吗？
A: 可以。在同一局域网时，Tailscale 会优先使用局域网连接，速度更快。

### Q: Tailscale 会影响手机电池吗？
A: 影响很小。Tailscale 使用 UDP 保活，电池消耗通常小于 1%/小时。

## 其他远程访问方案

如果您不想使用 Tailscale，还有其他选择：

### frp（内网穿透）
- 需要一台有公网 IP 的服务器
- 流量经过中转服务器
- 配置较复杂

### ngrok
- 第三方服务，免费版有限制
- 配置简单，但需要信任第三方

### WireGuard（自建 VPN）
- 完全自主控制
- 需要公网 IP 和服务器
- 配置复杂度最高

## 总结

使用 Tailscale 的远程访问架构：

```
Mac 电脑 (100.64.0.1)
    ↓ Tailscale 虚拟网络（加密 P2P）
手机 (100.64.0.2)
    ↓ AutoGLM Helper (HTTP Server on :8080)
手机操作
```

配置完成后，无论您在家、在公司还是在咖啡店，Mac 和手机都可以像在同一个网络一样通信！

## 相关链接

- Tailscale 官网：https://tailscale.com
- Tailscale 文档：https://tailscale.com/kb
- Tailscale Android 下载：https://play.google.com/store/apps/details?id=com.tailscale.ipn
- WireGuard 官网：https://www.wireguard.com
