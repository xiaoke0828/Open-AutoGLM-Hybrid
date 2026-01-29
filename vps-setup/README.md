# VPS 部署说明（腾讯云）

本目录包含腾讯云 VPS 端的 frp 服务器部署脚本。

## 📋 部署前准备

### 1. 腾讯云安全组配置

在腾讯云控制台配置安全组，开放以下端口：

| 端口 | 协议 | 用途 | 必须 |
|------|------|------|------|
| 7000 | TCP | frp 客户端连接 | ✅ 是 |
| 7500 | TCP | frp Dashboard | ⚪ 可选 |
| 8080 | TCP | Web 界面访问 | ✅ 是 |

**配置步骤：**
1. 登录腾讯云控制台
2. 找到你的云服务器实例
3. 点击"安全组" → "编辑规则"
4. 添加入站规则，允许上述端口

### 2. 系统要求

- 操作系统：Linux（CentOS 7+、Ubuntu 18.04+、Debian 9+）
- 架构：x86_64 或 aarch64
- 内存：≥ 512MB
- 磁盘：≥ 1GB 可用空间

## 🚀 快速部署（10 分钟）

### 步骤 1：上传文件到 VPS

**方法 A：使用 scp**
```bash
# 在本地（Mac）执行
cd vps-setup
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

### 步骤 2：修改配置文件

```bash
# 在 VPS 上执行
cd /root/frp-setup  # 或 /root/Open-AutoGLM-Hybrid/vps-setup
nano frps.ini

# 修改以下两项（必须）：
# 1. dashboard_pwd = 你的Dashboard密码
# 2. authentication_token = 你的认证Token（至少16位随机字符）
```

**生成随机 Token：**
```bash
openssl rand -base64 24
```

### 步骤 3：运行部署脚本

```bash
chmod +x install-frps.sh
sudo ./install-frps.sh
```

部署脚本会自动：
1. 下载 frp v0.55.1
2. 安装到 `/usr/local/frp/`
3. 配置 systemd 服务
4. 配置防火墙（如果有）
5. 启动服务

### 步骤 4：验证部署

```bash
# 查看服务状态
sudo systemctl status frps

# 查看日志
sudo tail -f /var/log/frps.log

# 查看端口监听
ss -tuln | grep 7000
```

**访问 Dashboard：**
```
http://你的VPS_IP:7500
用户名：admin
密码：你在 frps.ini 中设置的密码
```

## 🔧 配置说明

### frps.ini 配置文件

```ini
[common]
bind_port = 7000              # frp 服务端口（客户端连接）
dashboard_port = 7500         # Dashboard 端口
dashboard_user = admin        # Dashboard 用户名
dashboard_pwd = 修改我        # Dashboard 密码（必须修改）
authentication_token = 修改我 # 认证 Token（必须修改，与客户端一致）
log_file = /var/log/frps.log  # 日志文件
log_level = info              # 日志级别
log_max_days = 7              # 日志保留天数
max_pool_count = 50           # 最大连接池
heartbeat_timeout = 90        # 心跳超时（秒）
allow_ports = 8080-8090       # 允许映射的端口范围
```

## 📝 常用命令

```bash
# 查看服务状态
sudo systemctl status frps

# 启动服务
sudo systemctl start frps

# 停止服务
sudo systemctl stop frps

# 重启服务
sudo systemctl restart frps

# 查看实时日志
sudo tail -f /var/log/frps.log

# 查看 systemd 日志
sudo journalctl -u frps -f

# 编辑配置
sudo nano /usr/local/frp/frps.ini
# 修改后需要重启服务
sudo systemctl restart frps
```

## 🔒 安全建议

1. **修改默认 Token**
   - 使用至少 16 位随机字符
   - 定期更换（每 3-6 个月）

2. **限制 Dashboard 访问**
   - 如果不需要，可以注释掉 `dashboard_port`
   - 或者只允许特定 IP 访问（通过防火墙）

3. **监控日志**
   - 定期检查 `/var/log/frps.log`
   - 关注异常连接和失败尝试

4. **更新 frp**
   - 定期检查 frp 新版本
   - 更新命令：重新运行 `install-frps.sh`

## 🐛 故障排查

### 问题 1：服务无法启动

```bash
# 查看详细错误日志
sudo journalctl -u frps -n 50

# 检查配置文件语法
/usr/local/frp/frps -c /usr/local/frp/frps.ini verify
```

### 问题 2：端口被占用

```bash
# 查看端口占用
sudo ss -tuln | grep 7000

# 杀死占用进程
sudo lsof -ti:7000 | xargs kill -9
```

### 问题 3：客户端无法连接

1. **检查安全组**：确保腾讯云安全组开放了 7000 端口
2. **检查防火墙**：
   ```bash
   # CentOS/RHEL
   sudo firewall-cmd --list-all

   # Ubuntu/Debian
   sudo ufw status
   ```
3. **检查 Token**：确保客户端和服务端的 `authentication_token` 一致

### 问题 4：Dashboard 无法访问

```bash
# 检查 7500 端口是否监听
sudo ss -tuln | grep 7500

# 查看日志
sudo tail -f /var/log/frps.log | grep dashboard
```

## 📊 性能优化

### 针对低配 VPS（1核 1GB）

修改 `frps.ini`：
```ini
max_pool_count = 20          # 降低连接池
log_level = warn             # 减少日志输出
```

### 针对高配 VPS（2核 4GB+）

修改 `frps.ini`：
```ini
max_pool_count = 100         # 增加连接池
log_level = info
```

## 📦 卸载

```bash
# 停止并禁用服务
sudo systemctl stop frps
sudo systemctl disable frps

# 删除服务文件
sudo rm /etc/systemd/system/frps.service

# 删除程序文件
sudo rm -rf /usr/local/frp

# 删除日志文件
sudo rm /var/log/frps.log

# 重载 systemd
sudo systemctl daemon-reload
```

## 📞 获取帮助

- frp 官方文档：https://gofrp.org/docs/
- GitHub Issues：https://github.com/fatedier/frp/issues
- 项目文档：`../docs/FRP_WEB_DEPLOYMENT.md`
