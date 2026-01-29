# frp 公网访问部署说明

生成时间: Thu Jan 29 18:07:28 CST 2026

---

## 📋 配置信息

### VPS 信息
- **IP 地址**: 193.112.94.2
- **Dashboard**: http://193.112.94.2:7500
  - 用户名: admin
  - 密码: `BwKqE6lLomB87LgOmGA1XWhusbSR6uaT`

### Web 服务访问
- **公网地址**: http://193.112.94.2:8080
- **认证 Token**: 启动 Mac 服务器后在日志中查看

---

## 🚀 部署步骤

### 第 1 步：VPS 端部署（5 分钟）

#### 1.1 上传配置文件

```bash
# 在本地 Mac 执行
cd vps-setup
scp frps.ini root@193.112.94.2:/root/
scp install-frps.sh root@193.112.94.2:/root/
```

#### 1.2 安装 frps

```bash
# SSH 登录到 VPS
ssh root@193.112.94.2

# 执行安装脚本
cd /root
chmod +x install-frps.sh
sudo ./install-frps.sh
```

#### 1.3 配置腾讯云安全组

登录腾讯云控制台，开放以下端口：
- **7000** - frp 服务端（必须）
- **8080** - Web 访问（必须）
- **7500** - Dashboard（可选）

**配置路径**：
控制台 → 云服务器 → 安全组 → 入站规则 → 添加规则

**规则配置**：
```
协议：TCP
端口：7000,8080,7500
来源：0.0.0.0/0
策略：允许
```

#### 1.4 验证服务

```bash
# 查看 frps 状态
sudo systemctl status frps

# 查看端口监听
sudo ss -tuln | grep -E "7000|8080|7500"

# 预期输出（看到这些端口即为正常）
# tcp   LISTEN 0.0.0.0:7000
# tcp   LISTEN 0.0.0.0:7500
```

---

### 第 2 步：Mac 端配置（3 分钟）

#### 2.1 下载 frpc

```bash
# 在 Mac 上执行
cd web-server

# 下载 frpc（macOS ARM64）
curl -L -o frpc.tar.gz https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_darwin_arm64.tar.gz

# 解压
tar -xzf frpc.tar.gz
mv frp_0.52.3_darwin_arm64/frpc .
chmod +x frpc
rm -rf frp_0.52.3_darwin_arm64 frpc.tar.gz

echo "✅ frpc 已安装"
```

#### 2.2 启动 frpc

```bash
# 确保 Web 服务器已运行
source venv/bin/activate
python app.py &

# 启动 frpc（新终端窗口）
./frpc -c frpc.ini
```

**成功输出**：
```
[web-autoglm] start proxy success
```

---

### 第 3 步：测试访问（2 分钟）

#### 3.1 查看 Dashboard

访问：http://193.112.94.2:7500

输入：
- 用户名：admin
- 密码：`BwKqE6lLomB87LgOmGA1XWhusbSR6uaT`

应该看到：
- ✅ `web-autoglm` 连接状态：在线

#### 3.2 访问 Web 界面

访问：http://193.112.94.2:8080

输入认证 Token（从 Mac 服务器启动日志复制）

#### 3.3 提交测试任务

任务：`打开淘宝`

---

## 🔧 维护命令

### VPS 端

```bash
# 查看状态
sudo systemctl status frps

# 重启服务
sudo systemctl restart frps

# 查看日志
sudo tail -f /var/log/frps.log

# 停止服务
sudo systemctl stop frps
```

### Mac 端

```bash
# 启动 frpc
cd web-server
./frpc -c frpc.ini

# 后台运行
nohup ./frpc -c frpc.ini > logs/frpc.log 2>&1 &

# 停止 frpc
pkill frpc

# 查看日志
tail -f logs/frpc.log
```

---

## 🐛 故障排除

### 问题 1：公网无法访问

**检查清单**：
- [ ] VPS frps 服务是否运行？`sudo systemctl status frps`
- [ ] 腾讯云安全组是否开放端口？（7000, 8080）
- [ ] Mac frpc 是否连接成功？查看日志
- [ ] 防火墙是否阻止？`sudo ufw status`

### 问题 2：frpc 连接失败

**错误**：`connect to server failed`

**解决**：
```bash
# 1. 检查 VPS IP 是否正确
ping 193.112.94.2

# 2. 检查 VPS 端口是否开放
telnet 193.112.94.2 7000

# 3. 检查 Auth Token 是否一致
grep authentication_token vps-setup/frps.ini
grep authentication_token web-server/frpc.ini
```

### 问题 3：Dashboard 无法访问

**检查**：
```bash
# VPS 端检查端口
sudo ss -tuln | grep 7500

# 本地测试
curl http://193.112.94.2:7500
```

---

## 📚 相关资源

- **frp 官方文档**：https://gofrp.org/docs/
- **GitHub 仓库**：https://github.com/fatedier/frp
- **腾讯云安全组**：https://console.cloud.tencent.com/cvm/securitygroup

---

**祝部署顺利！** 🚀
