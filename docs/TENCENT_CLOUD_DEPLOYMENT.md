# 腾讯云服务器部署指南

本指南将帮助您在腾讯云服务器上部署 Open-AutoGLM，实现远程控制 Android 手机的功能。

**适用场景**：
- 需要 24/7 不间断运行的自动化任务
- 多台手机的集中管理
- 远程访问和控制
- 高性能 AI 推理

**推荐配置**：
- 服务器：腾讯云轻量应用服务器 2核4G（约 ¥40/月）
- 系统：Ubuntu 22.04 LTS
- 带宽：按需选择（建议 ≥5Mbps）

---

## 目录

1. [购买和配置腾讯云服务器](#1-购买和配置腾讯云服务器)
2. [连接服务器](#2-连接服务器)
3. [配置服务器环境](#3-配置服务器环境)
4. [部署 Open-AutoGLM](#4-部署-open-autoglm)
5. [配置手机连接](#5-配置手机连接)
6. [测试部署](#6-测试部署)
7. [配置开机自启（可选）](#7-配置开机自启可选)
8. [配置公网访问（可选）](#8-配置公网访问可选)
9. [故障排除](#9-故障排除)

---

## 1. 购买和配置腾讯云服务器

### 步骤 1.1：登录腾讯云控制台

1. 访问 [腾讯云官网](https://cloud.tencent.com/)
2. 登录您的腾讯云账号
3. 进入 [轻量应用服务器控制台](https://console.cloud.tencent.com/lighthouse/instance/index)

### 步骤 1.2：购买服务器

1. 点击 **新建** 按钮
2. 选择配置：
   - **地域**：选择距离您最近的地域（如广州、上海、北京）
   - **镜像**：选择 `Ubuntu 22.04 LTS`
   - **实例套餐**：推荐 `2核4GB` 或更高
   - **购买时长**：按需选择
3. 设置实例名称：如 `AutoGLM-Server`
4. 确认订单并支付

### 步骤 1.3：配置防火墙规则

**重要**：必须开放必要的端口，否则无法访问服务器。

1. 在服务器列表中，点击您的服务器进入详情页
2. 进入 **防火墙** 标签页
3. 点击 **添加规则**，添加以下规则：

| 应用类型 | 协议 | 端口 | 来源 | 策略 | 说明 |
|---------|------|------|------|------|------|
| 自定义 | TCP | 22 | 0.0.0.0/0 | 允许 | SSH 登录 |
| 自定义 | TCP | 8000 | 0.0.0.0/0 | 允许 | Web 界面（可选） |
| 自定义 | TCP | 7000 | 0.0.0.0/0 | 允许 | frp 服务端（可选） |

**安全建议**：
- 如果只需要自己访问，将来源改为 `您的IP/32`（更安全）
- 部署完成后可以随时调整防火墙规则

### 步骤 1.4：重置或设置密码

1. 在服务器详情页，点击 **重置密码**
2. 设置一个强密码（建议使用密码管理器生成）
3. 确认并记录密码（后续 SSH 登录需要）

---

## 2. 连接服务器

### 方法一：使用腾讯云网页终端（推荐新手）

1. 在服务器列表中，点击服务器右侧的 **登录** 按钮
2. 选择 **使用 WebShell 登录**
3. 输入用户名 `ubuntu` 和密码
4. 成功登录后，您将看到命令行界面

### 方法二：使用本地 SSH 客户端（推荐）

**macOS/Linux**：
```bash
# 获取服务器公网 IP（在服务器详情页查看）
# 替换为您的实际 IP
ssh ubuntu@YOUR_SERVER_IP

# 首次连接会提示：Are you sure you want to continue connecting (yes/no)?
# 输入 yes 并回车
# 然后输入密码
```

**Windows**：
- 使用 [PuTTY](https://www.putty.org/) 或 [MobaXterm](https://mobaxterm.mobatek.net/)
- 主机名：填入服务器公网 IP
- 端口：22
- 用户名：ubuntu
- 密码：您设置的密码

---

## 3. 配置服务器环境

### 步骤 3.1：更新系统

```bash
# 更新软件包列表
sudo apt update

# 升级已安装的软件包（可选，但推荐）
sudo apt upgrade -y
```

### 步骤 3.2：安装必要软件

```bash
# 安装 Git、Python3、pip 等基础工具
sudo apt install -y git python3 python3-pip python3-venv curl wget

# 验证安装
python3 --version  # 应显示 Python 3.10.x 或更高
git --version      # 应显示 git 版本
```

### 步骤 3.3：配置时区（可选）

```bash
# 查看当前时区
timedatectl

# 设置为中国时区
sudo timedatectl set-timezone Asia/Shanghai

# 验证
date  # 应显示北京时间
```

### 步骤 3.4：创建工作目录

```bash
# 创建项目目录
mkdir -p ~/autoglm-server
cd ~/autoglm-server
```

---

## 4. 部署 Open-AutoGLM

### 步骤 4.1：克隆项目

```bash
# 克隆项目到服务器
git clone https://github.com/xiaoke0828/Open-AutoGLM-Hybrid.git
cd Open-AutoGLM-Hybrid

# 查看项目结构
ls -lh
```

### 步骤 4.2：使用部署脚本（自动化）

我们提供了自动化部署脚本，类似于 Mac 服务器方案：

```bash
# 进入 mac-server 目录（腾讯云服务器也使用此脚本）
cd mac-server

# 运行部署脚本
bash deploy-mac.sh
```

**部署过程说明**：
- ✅ 脚本会自动检测系统（Ubuntu 而非 macOS，但兼容）
- ✅ 安装 Python 虚拟环境和依赖（pillow、requests）
- ✅ 克隆 Open-AutoGLM 项目
- ✅ 自动检测手机 IP（Tailscale 或局域网）
- ✅ 生成配置文件 `config.env`

**注意**：
- 部署脚本会提示检测到非 macOS 系统，但会继续执行（兼容 Linux）
- 如果自动检测手机 IP 失败，需要手动输入（见下一步）

### 步骤 4.3：配置 API Key 和手机 IP

部署完成后，需要编辑配置文件：

```bash
# 编辑配置文件
nano ~/autoglm-server/config.env
```

修改以下内容：

```bash
# GRS AI API Key（必填）
export PHONE_AGENT_API_KEY="your_api_key_here"  # ← 替换为您的实际 API Key

# 手机 AutoGLM Helper 地址
# 如果使用 Tailscale（推荐）
export PHONE_HELPER_URL="http://100.64.0.2:8080"  # ← 替换为手机的 Tailscale IP

# 如果使用公网（需要配置端口转发或 frp）
# export PHONE_HELPER_URL="http://YOUR_PHONE_PUBLIC_IP:8080"

# 日志级别
export LOG_LEVEL="INFO"
```

**保存文件**：
- 按 `Ctrl + O` 保存
- 按 `Ctrl + X` 退出

**获取 API Key**：
- 如果使用 GRS AI：登录 [GRS AI 官网](https://grsai.com/) → API 管理 → 创建 API Key
- 如果使用其他服务（如 OpenAI）：修改 `PHONE_AGENT_BASE_URL`

---

## 5. 配置手机连接

### 方案 A：使用 Tailscale（推荐，最简单）

**为什么推荐 Tailscale？**
- ✅ 无需公网 IP
- ✅ 无需配置防火墙和端口转发
- ✅ 点对点加密，安全可靠
- ✅ 跨平台支持（手机、服务器、电脑）

**步骤 5.A.1：在手机上安装 Tailscale**

1. 在手机上安装 [Tailscale 客户端](https://tailscale.com/download)
   - Android：从 Google Play 或 [F-Droid](https://f-droid.org/) 下载
   - iOS：从 App Store 下载

2. 打开 Tailscale，使用 Google/GitHub/Email 登录

3. 允许 VPN 权限

4. 记录手机的 Tailscale IP（通常是 `100.64.0.x` 或 `100.x.x.x`）
   - 在 Tailscale APP 中查看

**步骤 5.A.2：在服务器上安装 Tailscale**

```bash
# 安装 Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 启动 Tailscale 并登录
sudo tailscale up

# 终端会显示一个 URL，复制到浏览器打开并授权
# 授权完成后，返回终端

# 查看 Tailscale 状态
tailscale status

# 您应该看到手机设备已列出
```

**步骤 5.A.3：测试连接**

```bash
# 测试 ping 手机（替换为您的手机 Tailscale IP）
ping 100.64.0.2

# 测试 AutoGLM Helper 连接
curl http://100.64.0.2:8080/status

# 预期输出：{"status":"ok","accessibility_enabled":true}
```

**步骤 5.A.4：更新配置文件**

```bash
nano ~/autoglm-server/config.env

# 修改 PHONE_HELPER_URL
export PHONE_HELPER_URL="http://100.64.0.2:8080"  # 替换为实际 IP
```

---

### 方案 B：使用 frp 内网穿透（适用于无 Tailscale）

如果无法使用 Tailscale，可以使用 frp 将手机端口映射到服务器公网 IP。

**架构**：
```
手机 (localhost:8080) → frp 客户端 (Termux)
                          ↓
                    frp 服务端 (腾讯云) → 公网 IP:7080
```

**详细步骤**：参考 [FRP_WEB_DEPLOYMENT.md](FRP_WEB_DEPLOYMENT.md)

**快速配置**：

1. 在服务器上安装 frp 服务端：

```bash
cd ~/autoglm-server
wget https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_linux_amd64.tar.gz
tar -xzf frp_0.52.3_linux_amd64.tar.gz
cd frp_0.52.3_linux_amd64

# 配置 frps.toml
cat > frps.toml << 'EOF'
bindPort = 7000
EOF

# 启动 frp 服务端
./frps -c frps.toml &
```

2. 在手机 Termux 中安装 frp 客户端：

```bash
# 在 Termux 中
pkg install wget
wget https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_linux_arm64.tar.gz
tar -xzf frp_0.52.3_linux_arm64.tar.gz
cd frp_0.52.3_linux_arm64

# 配置 frpc.toml（替换 YOUR_SERVER_IP）
cat > frpc.toml << 'EOF'
serverAddr = "YOUR_SERVER_IP"
serverPort = 7000

[[proxies]]
name = "autoglm-helper"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8080
remotePort = 7080
EOF

# 启动 frp 客户端
./frpc -c frpc.toml &
```

3. 更新服务器配置：

```bash
nano ~/autoglm-server/config.env

# 使用 localhost（因为 frp 映射到本地）
export PHONE_HELPER_URL="http://localhost:7080"
```

---

## 6. 测试部署

### 步骤 6.1：启动服务

```bash
cd ~/autoglm-server

# 启动服务（使用增强版启动脚本）
./start-server.sh
```

**预期输出**：
```
[信息] 正在启动 Open-AutoGLM Mac 服务器...

[信息] 加载配置文件...
[信息] 测试手机连接: http://100.64.0.2:8080
[成功] 手机已连接（无障碍模式）

[成功] 前置检查通过

[信息] 启动 Open-AutoGLM...
配置信息:
  - 手机地址: http://100.64.0.2:8080
  - API 基础 URL: https://api.grsai.com/v1
  - 日志级别: INFO

Open-AutoGLM 已启动！
```

### 步骤 6.2：测试基础功能

**方法 1：命令行测试**（推荐）

在另一个 SSH 终端中：

```bash
# 测试手机连接
curl http://YOUR_PHONE_IP:8080/status

# 测试截图
curl http://YOUR_PHONE_IP:8080/screenshot | jq '.success'

# 测试点击（不会实际执行，只是验证连接）
curl -X POST http://YOUR_PHONE_IP:8080/tap \
  -H "Content-Type: application/json" \
  -d '{"x": 500, "y": 500}'
```

**方法 2：通过 Open-AutoGLM CLI**（完整测试）

在 Open-AutoGLM 启动的终端中，输入任务：

```
> 帮我打开淘宝
```

如果一切正常，您应该看到：
1. AI 分析任务
2. 手机自动执行操作（打开淘宝 APP）
3. 返回执行结果

### 步骤 6.3：验证部署成功

✅ **部署成功的标志**：
- 启动脚本无错误输出
- 手机连接验证通过
- 能够接收和执行任务
- 手机屏幕显示相应操作

❌ **如果遇到问题**：
- 查看错误提示（启动脚本会给出详细的故障排除指引）
- 检查配置文件（API Key、手机 IP）
- 检查手机上的 AutoGLM Helper 是否运行
- 检查无障碍服务是否开启
- 参考下方的 [故障排除](#9-故障排除) 章节

---

## 7. 配置开机自启（可选）

### 步骤 7.1：创建 systemd 服务

```bash
# 创建服务文件
sudo nano /etc/systemd/system/autoglm.service
```

填入以下内容：

```ini
[Unit]
Description=Open-AutoGLM Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/autoglm-server
ExecStart=/home/ubuntu/autoglm-server/start-server.sh
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**保存文件**：
- 按 `Ctrl + O` 保存
- 按 `Ctrl + X` 退出

### 步骤 7.2：启用和启动服务

```bash
# 重新加载 systemd 配置
sudo systemctl daemon-reload

# 启用开机自启
sudo systemctl enable autoglm.service

# 启动服务
sudo systemctl start autoglm.service

# 查看服务状态
sudo systemctl status autoglm.service
```

### 步骤 7.3：管理服务

```bash
# 停止服务
sudo systemctl stop autoglm.service

# 重启服务
sudo systemctl restart autoglm.service

# 查看日志
sudo journalctl -u autoglm.service -f
```

---

## 8. 配置公网访问（可选）

如果需要通过浏览器访问 Web 界面，可以部署 Web 服务器。

### 步骤 8.1：部署 Web 界面

```bash
# 进入项目目录
cd ~/autoglm-server/Open-AutoGLM-Hybrid

# 安装 Web 服务器依赖
pip3 install flask flask-cors

# 复制 Web 服务器文件
cp -r web-server ~/autoglm-server/

# 启动 Web 服务器
cd ~/autoglm-server/web-server
python3 app.py &
```

### 步骤 8.2：配置 Nginx 反向代理（可选）

```bash
# 安装 Nginx
sudo apt install -y nginx

# 创建配置文件
sudo nano /etc/nginx/sites-available/autoglm
```

填入以下内容：

```nginx
server {
    listen 80;
    server_name YOUR_DOMAIN_OR_IP;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

**启用配置**：

```bash
# 创建软链接
sudo ln -s /etc/nginx/sites-available/autoglm /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
```

**访问 Web 界面**：
- 打开浏览器，访问 `http://YOUR_SERVER_IP`
- 您应该看到 Open-AutoGLM Web 界面

---

## 9. 故障排除

### 问题 1：无法连接到手机

**症状**：
```
[错误] 无法连接到手机: http://100.64.0.2:8080
```

**排查步骤**：

1. **检查手机上的 AutoGLM Helper 是否运行**
   ```bash
   # 在手机 Termux 中
   curl http://localhost:8080/status
   ```
   - 预期输出：`{"status":"ok","accessibility_enabled":true}`
   - 如果失败：启动 AutoGLM Helper APP

2. **检查无障碍服务是否开启**
   - 手机：设置 → 辅助功能 → 已下载的服务 → AutoGLM Helper → 开启

3. **检查 Tailscale 连接**
   ```bash
   # 在服务器上
   tailscale status

   # 应该看到手机设备
   # 例如：100.64.0.2   android-phone    xiaoke@     linux   -
   ```

   - 如果看不到手机：重启手机上的 Tailscale APP

4. **测试网络连通性**
   ```bash
   # 在服务器上 ping 手机
   ping 100.64.0.2

   # 测试 HTTP 连接
   curl -v http://100.64.0.2:8080/status
   ```

### 问题 2：API Key 无效

**症状**：
```
[错误] API Key 未配置或无效
```

**解决方案**：

1. **检查配置文件**
   ```bash
   cat ~/autoglm-server/config.env | grep PHONE_AGENT_API_KEY
   ```

   - 确保不是 `your_api_key_here`
   - 确保格式正确（无多余空格、引号）

2. **验证 API Key**
   - 登录 GRS AI 官网，检查 API Key 是否有效
   - 检查 API Key 的配额和权限

3. **重新加载配置**
   ```bash
   source ~/autoglm-server/config.env
   echo $PHONE_AGENT_API_KEY  # 应显示您的 API Key
   ```

### 问题 3：部署脚本失败

**症状**：
```
deploy-mac.sh: line 42: brew: command not found
```

**解决方案**：

部署脚本是为 macOS 设计的，但可以跳过 Homebrew 检查：

1. **手动安装依赖**
   ```bash
   # Ubuntu/Debian
   sudo apt install -y python3 python3-pip python3-venv git

   # 创建虚拟环境
   python3 -m venv ~/autoglm-server/venv
   source ~/autoglm-server/venv/bin/activate

   # 安装 Python 依赖
   pip install pillow requests
   ```

2. **克隆 Open-AutoGLM**
   ```bash
   cd ~/autoglm-server
   git clone https://github.com/zai-org/Open-AutoGLM.git
   ```

3. **手动创建配置文件**
   ```bash
   cat > ~/autoglm-server/config.env << 'EOF'
   export PHONE_AGENT_API_KEY="your_api_key_here"
   export PHONE_HELPER_URL="http://100.64.0.2:8080"
   export LOG_LEVEL="INFO"
   EOF
   ```

### 问题 4：frp 连接失败

**症状**：
```
frpc: dial tcp YOUR_SERVER_IP:7000: connection refused
```

**解决方案**：

1. **检查 frp 服务端是否运行**
   ```bash
   # 在服务器上
   ps aux | grep frps

   # 如果没有运行，重新启动
   cd ~/autoglm-server/frp_0.52.3_linux_amd64
   ./frps -c frps.toml &
   ```

2. **检查防火墙规则**
   - 确保腾讯云防火墙已开放 7000 端口
   - 检查服务器本地防火墙：
     ```bash
     sudo ufw status
     # 如果启用了，开放端口
     sudo ufw allow 7000/tcp
     ```

3. **检查配置文件**
   ```bash
   # 服务器端
   cat ~/autoglm-server/frp_0.52.3_linux_amd64/frps.toml

   # 手机端
   cat ~/frp_0.52.3_linux_arm64/frpc.toml
   ```

### 问题 5：服务启动后无响应

**症状**：
服务启动成功，但无法执行任务

**排查步骤**：

1. **查看日志**
   ```bash
   # 如果使用 systemd
   sudo journalctl -u autoglm.service -f

   # 如果手动启动
   # 查看启动终端的输出
   ```

2. **检查进程**
   ```bash
   ps aux | grep python
   ```

3. **测试基础功能**
   ```bash
   # 测试截图
   curl http://YOUR_PHONE_IP:8080/screenshot

   # 测试点击
   curl -X POST http://YOUR_PHONE_IP:8080/tap \
     -H "Content-Type: application/json" \
     -d '{"x": 500, "y": 500}'
   ```

### 问题 6：内存不足

**症状**：
```
MemoryError: Unable to allocate array
```

**解决方案**：

1. **升级服务器配置**
   - 推荐至少 2GB 内存
   - 如果使用大型 AI 模型，建议 4GB 或更高

2. **配置 swap 交换空间**
   ```bash
   # 创建 2GB swap 文件
   sudo fallocate -l 2G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile

   # 永久启用（添加到 /etc/fstab）
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

3. **优化 AI 模型**
   - 使用更小的模型（如 gpt-3.5-turbo 而非 gpt-4）
   - 在配置文件中修改 `PHONE_AGENT_MODEL`

---

## 10. 性能优化建议

### 10.1 使用 CDN 加速（可选）

如果需要在多个地区访问，可以配置腾讯云 CDN：

1. 开通腾讯云 CDN 服务
2. 添加加速域名
3. 配置回源地址为您的服务器 IP
4. 修改 DNS 解析，将域名 CNAME 到 CDN 域名

### 10.2 数据库优化（如果使用）

如果您扩展了项目并使用数据库：

1. 安装 Redis（缓存）
   ```bash
   sudo apt install -y redis-server
   sudo systemctl enable redis-server
   ```

2. 配置数据库连接池
3. 使用索引优化查询

### 10.3 日志管理

```bash
# 配置日志轮转
sudo nano /etc/logrotate.d/autoglm

# 添加以下内容
/home/ubuntu/autoglm-server/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 ubuntu ubuntu
}
```

---

## 11. 安全建议

### 11.1 使用 SSH 密钥登录

```bash
# 在本地生成 SSH 密钥对
ssh-keygen -t rsa -b 4096

# 上传公钥到服务器
ssh-copy-id ubuntu@YOUR_SERVER_IP

# 禁用密码登录（可选）
sudo nano /etc/ssh/sshd_config
# 修改：PasswordAuthentication no
sudo systemctl restart sshd
```

### 11.2 配置防火墙

```bash
# 启用 UFW 防火墙
sudo ufw enable

# 允许 SSH
sudo ufw allow 22/tcp

# 允许必要的端口
sudo ufw allow 8000/tcp  # Web 界面
sudo ufw allow 7000/tcp  # frp 服务端

# 查看状态
sudo ufw status
```

### 11.3 定期更新系统

```bash
# 设置自动更新（可选）
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## 12. 成本估算

**腾讯云轻量应用服务器（2核4GB）**：
- 按月付费：约 ¥40-50/月
- 按年付费：约 ¥400-500/年（约 8.5 折）

**Tailscale 服务**：
- 个人用户：免费（最多 100 台设备）
- 团队用户：按需付费

**GRS AI API 费用**（按 token 计费）：
- 视频分析：约 ¥0.01-0.05/次
- 文本生成：约 ¥0.001-0.01/次
- 预计费用：约 ¥10-50/月（根据使用量）

**总成本估算**：约 ¥50-100/月

---

## 13. 总结

您已成功在腾讯云服务器上部署 Open-AutoGLM！

**部署架构**：
```
用户输入 → 腾讯云服务器 (Open-AutoGLM)
         → GRS AI (视觉分析 + 任务规划)
         → Tailscale/frp 连接
         → 手机 (AutoGLM Helper)
         → 执行操作
```

**下一步**：
- ✅ 测试各种自动化任务
- ✅ 配置开机自启（如需 24/7 运行）
- ✅ 配置 Web 界面（如需浏览器访问）
- ✅ 备份配置文件（`config.env`）
- ✅ 监控服务器资源使用情况

**相关文档**：
- [Tailscale 配置指南](TAILSCALE_GUIDE.md)
- [frp 内网穿透部署](FRP_WEB_DEPLOYMENT.md)
- [Web 界面使用手册](WEB_USER_MANUAL.md)
- [常见问题解答](../README.md#常见问题)

**技术支持**：
- GitHub Issues: https://github.com/xiaoke0828/Open-AutoGLM-Hybrid/issues
- 查看日志：`sudo journalctl -u autoglm.service -f`
- 参考故障排除章节

祝您使用愉快！🎉
