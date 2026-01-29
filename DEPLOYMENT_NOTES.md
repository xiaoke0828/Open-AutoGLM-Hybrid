# 部署注意事项

> **重要**：其他用户部署本项目前，请务必阅读此文档

---

## ⚠️ 必须完成的配置步骤

### 步骤 1：创建配置文件

```bash
cd web-server
cp .env.example .env
```

### 步骤 2：配置智谱 AI API Key

**获取 API Key**：

1. 访问：https://open.bigmodel.cn/usercenter/apikeys
2. 注册/登录（需要手机号和实名认证）
3. 点击"添加新的 API Key"
4. 复制生成的 Key（格式：`abc123def456.xyz789ghi012`）

**填入配置文件**：

```bash
nano .env

# 找到这一行
PHONE_AGENT_API_KEY=YOUR_API_KEY_HERE

# 替换为您的实际 Key
PHONE_AGENT_API_KEY=abc123def456.xyz789ghi012
```

**费用说明**：
- ✅ `autoglm-phone` 模型：**限时免费**
- ⚠️ 后续可能收费，请关注官方公告

### 步骤 3：配置手机 IP 地址

**获取手机 IP**：

**方法 A：使用 Tailscale**（推荐，支持远程）

```bash
# 1. 在手机安装 Tailscale APP
# 2. 在 Mac 安装 Tailscale
brew install tailscale
sudo tailscale up

# 3. 查看设备列表
tailscale status

# 4. 找到手机的 IP（通常是 100.x.x.x）
# 示例输出：
# 100.64.0.2   phone-xiaomi   ...

# 5. 配置到 .env
PHONE_HELPER_URL=http://100.64.0.2:8080
```

**方法 B：使用局域网 IP**（仅同一 WiFi）

```bash
# 1. 手机 WiFi 设置中查看 IP（例如 192.168.1.100）
# 2. 配置到 .env
PHONE_HELPER_URL=http://192.168.1.100:8080
```

### 步骤 4：验证配置

```bash
# 测试手机连接
curl http://YOUR_PHONE_IP:8080/status

# 预期输出
{"status":"ok","accessibility_enabled":true}
```

---

## 📱 手机端准备

### 安装 AutoGLM Helper

1. 下载 APK：从项目 Releases 页面下载
2. 安装到手机
3. 打开 APP

### 开启无障碍服务

1. 进入：设置 → 辅助功能 → 已下载的服务
2. 找到：AutoGLM Helper
3. 点击：开启服务

### 验证服务运行

打开手机上的 AutoGLM Helper APP，应该显示：
- ✅ 服务状态：运行中
- ✅ 无障碍权限：已开启
- ✅ HTTP 服务：http://手机IP:8080

---

## 🌐 公网访问配置（可选）

如果需要在外网访问 Web 界面，有两种方案：

### 方案 A：使用 Tailscale（推荐）

**优势**：
- ✅ 配置简单，10 分钟完成
- ✅ 安全加密，P2P 直连
- ✅ 免费使用
- ✅ 支持手机、Mac 互联

**缺点**：
- ❌ 需要安装客户端
- ❌ 首次配置需要注册账号

**配置步骤**：

详见：[Tailscale 配置指南](docs/TAILSCALE_GUIDE.md)

### 方案 B：使用 frp 内网穿透

**优势**：
- ✅ 通过 HTTP/HTTPS 访问，无需客户端
- ✅ 可自定义域名
- ✅ 适合多人访问

**缺点**：
- ❌ 需要一台公网 VPS
- ❌ 配置较复杂
- ❌ 流量经过 VPS 中转

**配置步骤**：

详见：[frp 内网穿透部署指南](docs/FRP_WEB_DEPLOYMENT.md)

---

## 🔒 安全注意事项

### 敏感文件保护

**绝对不要提交到 Git**：
- ❌ `.env` - 包含 API Key
- ❌ `.auth_token` - 认证 Token
- ❌ `task_history.json` - 任务历史（可能包含隐私）
- ❌ `*.pid` - 运行时进程 ID
- ❌ `logs/` - 日志文件

这些文件已在 `.gitignore` 中排除，但请**务必检查**！

### API Key 安全

- ✅ 定期更换 API Key
- ✅ 不要分享给他人
- ✅ 不要截图包含 Key 的配置
- ✅ 泄露后立即删除并重新生成

### Web 服务安全

- ✅ 使用认证 Token（自动生成在 `.auth_token`）
- ✅ 生产环境建议使用 HTTPS
- ✅ 配置防火墙限制访问来源
- ✅ 定期查看访问日志

---

## 📦 依赖安装

### Python 依赖

```bash
cd web-server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**主要依赖**：
- Flask - Web 框架
- openai - AI 模型调用
- Pillow - 图像处理
- requests - HTTP 请求

### 系统要求

**Mac 电脑**：
- macOS 10.15+
- Python 3.9+
- 4GB+ RAM

**Android 手机**：
- Android 7.0+
- 2GB+ RAM
- 500MB 可用存储

---

## 🐛 常见问题

### 问题 1：API Key 无效

**错误信息**：
```
Error code: 401 - 令牌已过期或验证不正确
```

**解决方案**：
1. 检查 API Key 是否正确复制（包含点号）
2. 登录智谱 AI 平台确认 Key 状态
3. 删除旧 Key，重新生成新 Key
4. 更新 `.env` 文件并重启服务

### 问题 2：手机连接失败

**错误信息**：
```
❌ 手机控制器初始化失败
```

**解决方案**：
1. 检查手机 AutoGLM Helper 是否运行
2. 检查无障碍服务是否开启
3. 测试连接：`curl http://手机IP:8080/status`
4. 确认 Mac 和手机在同一网络

### 问题 3：端口被占用

**错误信息**：
```
Address already in use (Port 8000)
```

**解决方案**：
```bash
# 方式 1: 关闭占用端口的程序
lsof -i :8000
kill <PID>

# 方式 2: 修改端口
nano .env
# 修改 WEB_PORT=9000
```

---

## 📚 相关文档

- [快速开始指南](WEB_QUICK_START.md)
- [AI 功能使用指南](docs/WEB_AI_GUIDE.md)
- [frp 内网穿透部署](docs/FRP_WEB_DEPLOYMENT.md)
- [Tailscale 配置指南](docs/TAILSCALE_GUIDE.md)
- [腾讯云部署指南](docs/TENCENT_CLOUD_DEPLOYMENT.md)

---

## 💬 获取帮助

- **GitHub Issues**：https://github.com/xiaoke0828/Open-AutoGLM-Hybrid/issues
- **查看日志**：`tail -f web-server/logs/web-ai.log`
- **测试连接**：`curl http://手机IP:8080/status`

---

**祝您部署顺利！** 🚀
