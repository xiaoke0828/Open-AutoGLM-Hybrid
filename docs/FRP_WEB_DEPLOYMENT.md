# AutoGLM Web 界面 + frp 部署指南

本文档介绍如何通过腾讯云 VPS + frp 内网穿透，实现在外网通过浏览器控制家里 Mac 上的 Open-AutoGLM。

## 📋 架构概览

```
手机浏览器（外网）
    ↓ HTTPS
腾讯云 VPS（frp 服务端）
    ↓ frp 隧道
家里 Mac（frp 客户端 + Web 服务）
    ↓ HTTP
家里手机（AutoGLM Helper）
```

## 🎯 部署目标

- ✅ 在任何地方用手机浏览器访问：`http://VPS_IP:8080`
- ✅ 输入任务描述（如"打开微信，给张三发消息"）
- ✅ 实时查看执行日志和手机截图
- ✅ 查看历史任务记录

## 📦 前置准备

### 1. 腾讯云 VPS

- ✅ 已购买腾讯云服务器（最低配即可：1核 1GB）
- ✅ 操作系统：CentOS 7+、Ubuntu 18.04+、Debian 9+
- ✅ 公网 IP 地址（记下来，后面要用）

### 2. Mac 电脑（家里）

- ✅ macOS 10.13+
- ✅ 已安装 Python 3.7+（检查：`python3 --version`）
- ✅ 已部署 mac-server（参考 `QUICK_START_MAC.md`）
- ✅ 网络稳定（家庭宽带即可）

### 3. Android 手机

- ✅ 已安装 AutoGLM Helper
- ✅ 已启用无障碍权限
- ✅ 与 Mac 在同一局域网（或通过 Tailscale 连接）

### 4. API Key

- ✅ GRS AI API Key（从 https://grs.ai/ 获取）

---

## 🚀 部署步骤

### 阶段 1：VPS 端部署（10 分钟）

#### 步骤 1.1：上传部署脚本到 VPS

**方法 A：使用 scp**
```bash
# 在本地 Mac 执行
cd /Users/wk/Documents/Open-AutoGLM-Hybrid/vps-setup
scp -r * root@你的VPS_IP:/root/frp-setup/
```

**方法 B：使用 Git**
```bash
# 在 VPS 上执行
ssh root@你的VPS_IP
cd /root
git clone https://github.com/你的用户名/Open-AutoGLM-Hybrid.git
cd Open-AutoGLM-Hybrid/vps-setup
```

#### 步骤 1.2：修改 frp 配置

```bash
# 在 VPS 上执行
nano frps.ini

# 修改以下两项（必须）：
# 1. dashboard_pwd = 你的Dashboard密码（建议使用强密码）
# 2. authentication_token = 你的认证Token（至少16位）
```

**生成随机 Token：**
```bash
openssl rand -base64 24
# 示例输出：Kx9Yp2Qm7Zv3Bn5Hf8Wj1Rt4Lc6Dx
```

#### 步骤 1.3：运行部署脚本

```bash
chmod +x install-frps.sh
sudo ./install-frps.sh
```

部署脚本会自动：
1. 下载 frp v0.55.1
2. 安装到 `/usr/local/frp/`
3. 配置 systemd 服务
4. 配置防火墙
5. 启动 frp 服务

#### 步骤 1.4：配置安全组

**重要：** 在腾讯云控制台配置安全组，开放以下端口：

1. 登录腾讯云控制台
2. 找到你的云服务器实例
3. 点击"安全组" → "编辑规则"
4. 添加入站规则：

| 端口 | 协议 | 源地址 | 说明 |
|------|------|--------|------|
| 7000 | TCP | 0.0.0.0/0 | frp 服务端口（必须） |
| 7500 | TCP | 你的IP/32 | Dashboard（可选，建议限制 IP） |
| 8080 | TCP | 0.0.0.0/0 | Web 界面端口（必须） |

#### 步骤 1.5：验证部署

```bash
# 查看服务状态
sudo systemctl status frps

# 查看日志
sudo tail -f /var/log/frps.log

# 访问 Dashboard（可选）
# 浏览器打开: http://你的VPS_IP:7500
# 用户名: admin
# 密码: 你在 frps.ini 中设置的密码
```

---

### 阶段 2：Mac 端部署（10 分钟）

#### 步骤 2.1：进入项目目录

```bash
cd /Users/wk/Documents/Open-AutoGLM-Hybrid/web-server
```

#### 步骤 2.2：运行部署脚本

```bash
./deploy-web-frp.sh
```

脚本会提示你输入以下信息：

**frp 配置：**
- VPS IP 地址：填写你的腾讯云公网 IP
- frp 认证 Token：填写与 VPS 端一致的 Token

**Open-AutoGLM 配置：**
- 手机 IP 地址：填写手机的局域网 IP（查看 AutoGLM Helper 主页）
- GRS AI API Key：填写你的 API Key

部署脚本会自动：
1. 创建 Python 虚拟环境
2. 安装依赖
3. 下载 frp 客户端
4. 生成配置文件

#### 步骤 2.3：启动服务

```bash
./start-web-frp.sh
```

启动后会显示：
```
======================================"
✅ 服务启动成功！
======================================"

📊 服务状态：
   frp 客户端: 运行中 (PID: 12345)
   Web 服务: 运行中 (PID: 12346)

🌐 访问地址：
   公网: http://123.456.789.0:8080
   本地: http://localhost:5000

🔑 认证 Token：
   Ab3Cd9Ef2Gh5Jk8Lm1Pq4Rs7Tv0Wx6Yz
   (保存此 Token，用于 Web 界面登录)
```

**保存好认证 Token**，稍后登录 Web 界面时需要用到。

---

### 阶段 3：测试访问（5 分钟）

#### 步骤 3.1：本地测试

```bash
# 在 Mac 上打开浏览器访问
open http://localhost:5000
```

#### 步骤 3.2：公网测试

1. **在手机浏览器中访问**：`http://你的VPS_IP:8080`
2. **输入认证 Token**（从 Mac 启动日志复制）
3. **提交测试任务**：比如"打开设置"
4. **查看执行过程**：实时日志和截图

---

## 📖 使用指南

### Web 界面功能

#### 1. 首页 - 任务提交

- **输入任务描述**：自然语言描述你想让手机做什么
  - 示例 1："打开微信，给张三发消息说晚上见"
  - 示例 2："打开抖音，搜索猫咪视频"
  - 示例 3："打开设置，关闭蓝牙"

- **提交任务**：点击"提交任务"按钮

- **查看最近任务**：页面底部显示最近 10 条任务记录

#### 2. 任务详情页 - 实时监控

- **左侧：执行日志**
  - 实时显示任务执行步骤
  - 显示任务状态（等待中/执行中/已完成/失败）
  - 显示任务耗时

- **右侧：手机截图**
  - 实时显示手机屏幕
  - 自动更新截图

#### 3. 历史记录页

- 查看所有历史任务
- 按状态筛选（全部/等待中/执行中/已完成/失败）
- 点击任务查看详情

### 常用命令

```bash
# 进入项目目录
cd /Users/wk/Documents/Open-AutoGLM-Hybrid/web-server

# 启动服务
./start-web-frp.sh

# 停止服务
./stop-web-frp.sh

# 查看 Web 服务日志
tail -f ../logs/web/app.log

# 查看 frp 日志
tail -f ../logs/frpc.log

# 重启服务
./stop-web-frp.sh && ./start-web-frp.sh
```

### VPS 端常用命令

```bash
# 查看 frps 状态
sudo systemctl status frps

# 重启 frps
sudo systemctl restart frps

# 查看 frps 日志
sudo tail -f /var/log/frps.log

# 查看 systemd 日志
sudo journalctl -u frps -f
```

---

## 🔒 安全建议

### 1. 强化 Token 认证

**定期更换 Token：**
```bash
# Mac 端
cd web-server
rm .auth_token
./start-web-frp.sh  # 重启时会生成新 Token
```

### 2. 使用 HTTPS（可选）

在 VPS 上配置 Nginx + Let's Encrypt：

```bash
# 安装 Nginx 和 Certbot
sudo apt install nginx certbot python3-certbot-nginx

# 配置 Nginx 反向代理
sudo nano /etc/nginx/sites-available/autoglm

# 添加以下配置：
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

# 启用配置
sudo ln -s /etc/nginx/sites-available/autoglm /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# 申请 SSL 证书
sudo certbot --nginx -d your-domain.com
```

### 3. IP 白名单（可选）

限制只允许特定 IP 访问：

```bash
# 在 VPS 防火墙中配置
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="你的IP" port protocol="tcp" port="8080" accept'
sudo firewall-cmd --reload
```

---

## 🐛 故障排查

### 问题 1：VPS 端 frps 无法启动

**检查步骤：**
```bash
# 查看详细错误
sudo journalctl -u frps -n 50

# 检查端口占用
sudo ss -tuln | grep 7000

# 验证配置文件
/usr/local/frp/frps -c /usr/local/frp/frps.ini verify
```

**常见原因：**
- 端口被占用 → 修改端口或杀死占用进程
- 配置语法错误 → 检查 `frps.ini` 格式
- 防火墙未开放 → 检查安全组和防火墙规则

### 问题 2：Mac 端 frpc 连接失败

**检查步骤：**
```bash
# 查看 frpc 日志
tail -f logs/frpc.log

# 测试 VPS 端口可达性
nc -zv 你的VPS_IP 7000
```

**常见原因：**
- Token 不一致 → 确保 `frpc.ini.local` 和 VPS 端 `frps.ini` 的 Token 一致
- VPS 防火墙未开放 7000 端口 → 检查安全组
- VPS 上 frps 未启动 → 在 VPS 上运行 `sudo systemctl start frps`

### 问题 3：Web 界面无法访问

**检查步骤：**
```bash
# 检查 Web 服务是否运行
ps aux | grep python

# 检查端口监听
lsof -i :5000

# 查看 Web 日志
tail -f logs/web/app.log
```

**常见原因：**
- Python 依赖未安装 → 重新运行 `./deploy-web-frp.sh`
- 端口被占用 → 修改 `.env` 中的 `WEB_PORT`
- frpc 未连接成功 → 先解决 frpc 连接问题

### 问题 4：提交任务后无响应

**检查步骤：**
```bash
# 查看任务执行日志
tail -f logs/web/app.log

# 检查手机连接
curl http://手机IP:8080/status
```

**常见原因：**
- 手机 AutoGLM Helper 未启动 → 启动 App
- 手机 IP 配置错误 → 检查 `.env` 中的 `PHONE_HELPER_URL`
- API Key 未配置 → 检查 `.env` 中的 `PHONE_AGENT_API_KEY`

### 问题 5：公网无法访问

**检查步骤：**
```bash
# 在 VPS 上检查端口监听
sudo ss -tuln | grep 8080

# 测试本地连接
curl http://127.0.0.1:8080

# 检查 frp 隧道状态
# 访问 Dashboard: http://VPS_IP:7500
```

**常见原因：**
- 安全组未开放 8080 端口 → 在腾讯云控制台配置
- frpc 隧道未建立 → 检查 Mac 端 frpc 日志
- VPS 防火墙阻止 → 运行 `sudo firewall-cmd --list-all` 检查

---

## 📊 性能优化

### 针对低配 VPS（1核 1GB）

**VPS 端 `frps.ini` 优化：**
```ini
max_pool_count = 20
log_level = warn
```

**Mac 端优化：**
```bash
# 降低日志级别
echo "LOG_LEVEL=WARNING" >> .env
```

### 针对多用户场景

**增加连接池：**
```ini
# VPS 端 frps.ini
max_pool_count = 100

# Mac 端 frpc.ini.local
pool_count = 10
```

---

## 📦 卸载

### Mac 端卸载

```bash
cd web-server

# 停止服务
./stop-web-frp.sh

# 删除虚拟环境
rm -rf venv

# 删除配置文件
rm .env frpc.ini.local .auth_token

# 删除 frpc
rm frpc

# 删除日志
rm -rf ../logs
```

### VPS 端卸载

```bash
# 停止并禁用服务
sudo systemctl stop frps
sudo systemctl disable frps

# 删除服务文件
sudo rm /etc/systemd/system/frps.service

# 删除程序文件
sudo rm -rf /usr/local/frp

# 删除日志
sudo rm /var/log/frps.log

# 重载 systemd
sudo systemctl daemon-reload
```

---

## 📞 获取帮助

- **frp 官方文档**：https://gofrp.org/docs/
- **Open-AutoGLM 文档**：https://github.com/zai-org/Open-AutoGLM
- **项目 Issues**：https://github.com/你的用户名/Open-AutoGLM-Hybrid/issues

---

## 🎉 完成！

现在你可以在任何地方用手机浏览器控制家里的手机了！

**下一步建议：**
1. 配置 HTTPS（更安全）
2. 设置自动启动（Mac 开机自启）
3. 监控服务状态（定时检查）
