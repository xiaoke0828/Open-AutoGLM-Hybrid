#!/bin/bash

# ============================================================
# frp 公网访问一键配置脚本
# VPS IP: 193.112.94.2
# ============================================================

set -e

echo "🚀 开始配置 frp 公网访问..."
echo ""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 生成随机密码
generate_password() {
    openssl rand -base64 24
}

# ==================== 步骤 1：生成安全密码 ====================
echo -e "${GREEN}步骤 1/5: 生成安全密码${NC}"

DASHBOARD_PWD=$(generate_password)
AUTH_TOKEN=$(generate_password)

echo "✅ Dashboard 密码: $DASHBOARD_PWD"
echo "✅ 认证 Token: $AUTH_TOKEN"
echo ""

# ==================== 步骤 2：更新 frps.ini ====================
echo -e "${GREEN}步骤 2/5: 更新 VPS 配置文件${NC}"

cat > frps.ini << EOF
# frp 服务端配置文件
# 用于腾讯云 VPS (193.112.94.2)

[common]
# frps 监听端口（用于客户端连接）
bind_port = 7000

# Dashboard 配置（用于查看连接状态）
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = ${DASHBOARD_PWD}

# 认证 token（必须与客户端一致）
authentication_token = ${AUTH_TOKEN}

# 日志配置
log_file = /var/log/frps.log
log_level = info
log_max_days = 7

# 最大连接池大小
max_pool_count = 50

# 心跳配置
heartbeat_timeout = 90

# 允许的端口范围
allow_ports = 8080-8090
EOF

echo "✅ frps.ini 已更新"
echo ""

# ==================== 步骤 3：生成 Mac 客户端配置 ====================
echo -e "${GREEN}步骤 3/5: 生成 Mac 客户端配置${NC}"

cat > ../web-server/frpc.ini << EOF
# frp 客户端配置文件
# 用于 Mac 电脑

[common]
# VPS 服务器地址和端口
server_addr = 193.112.94.2
server_port = 7000

# 认证 token（必须与服务端一致）
authentication_token = ${AUTH_TOKEN}

# 日志配置
log_file = logs/frpc.log
log_level = info

# Web 服务穿透配置
[web-autoglm]
type = tcp
local_ip = 127.0.0.1
local_port = 8000
remote_port = 8080
EOF

echo "✅ frpc.ini 已生成到 web-server/ 目录"
echo ""

# ==================== 步骤 4：保存配置信息 ====================
echo -e "${GREEN}步骤 4/5: 保存配置信息${NC}"

cat > ../web-server/.frp-config << EOF
# frp 配置信息（请妥善保管）
# 生成时间: $(date)

VPS_IP=193.112.94.2
DASHBOARD_URL=http://193.112.94.2:7500
DASHBOARD_USER=admin
DASHBOARD_PWD=${DASHBOARD_PWD}
AUTH_TOKEN=${AUTH_TOKEN}
WEB_URL=http://193.112.94.2:8080
EOF

chmod 600 ../web-server/.frp-config

echo "✅ 配置已保存到 web-server/.frp-config"
echo ""

# ==================== 步骤 5：生成部署说明 ====================
echo -e "${GREEN}步骤 5/5: 生成部署说明${NC}"

cat > DEPLOY_INSTRUCTIONS.md << EOF
# frp 公网访问部署说明

生成时间: $(date)

---

## 📋 配置信息

### VPS 信息
- **IP 地址**: 193.112.94.2
- **Dashboard**: http://193.112.94.2:7500
  - 用户名: admin
  - 密码: \`${DASHBOARD_PWD}\`

### Web 服务访问
- **公网地址**: http://193.112.94.2:8080
- **认证 Token**: 启动 Mac 服务器后在日志中查看

---

## 🚀 部署步骤

### 第 1 步：VPS 端部署（5 分钟）

#### 1.1 上传配置文件

\`\`\`bash
# 在本地 Mac 执行
cd vps-setup
scp frps.ini root@193.112.94.2:/root/
scp install-frps.sh root@193.112.94.2:/root/
\`\`\`

#### 1.2 安装 frps

\`\`\`bash
# SSH 登录到 VPS
ssh root@193.112.94.2

# 执行安装脚本
cd /root
chmod +x install-frps.sh
sudo ./install-frps.sh
\`\`\`

#### 1.3 配置腾讯云安全组

登录腾讯云控制台，开放以下端口：
- **7000** - frp 服务端（必须）
- **8080** - Web 访问（必须）
- **7500** - Dashboard（可选）

**配置路径**：
控制台 → 云服务器 → 安全组 → 入站规则 → 添加规则

**规则配置**：
\`\`\`
协议：TCP
端口：7000,8080,7500
来源：0.0.0.0/0
策略：允许
\`\`\`

#### 1.4 验证服务

\`\`\`bash
# 查看 frps 状态
sudo systemctl status frps

# 查看端口监听
sudo ss -tuln | grep -E "7000|8080|7500"

# 预期输出（看到这些端口即为正常）
# tcp   LISTEN 0.0.0.0:7000
# tcp   LISTEN 0.0.0.0:7500
\`\`\`

---

### 第 2 步：Mac 端配置（3 分钟）

#### 2.1 下载 frpc

\`\`\`bash
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
\`\`\`

#### 2.2 启动 frpc

\`\`\`bash
# 确保 Web 服务器已运行
source venv/bin/activate
python app.py &

# 启动 frpc（新终端窗口）
./frpc -c frpc.ini
\`\`\`

**成功输出**：
\`\`\`
[web-autoglm] start proxy success
\`\`\`

---

### 第 3 步：测试访问（2 分钟）

#### 3.1 查看 Dashboard

访问：http://193.112.94.2:7500

输入：
- 用户名：admin
- 密码：\`${DASHBOARD_PWD}\`

应该看到：
- ✅ \`web-autoglm\` 连接状态：在线

#### 3.2 访问 Web 界面

访问：http://193.112.94.2:8080

输入认证 Token（从 Mac 服务器启动日志复制）

#### 3.3 提交测试任务

任务：\`打开淘宝\`

---

## 🔧 维护命令

### VPS 端

\`\`\`bash
# 查看状态
sudo systemctl status frps

# 重启服务
sudo systemctl restart frps

# 查看日志
sudo tail -f /var/log/frps.log

# 停止服务
sudo systemctl stop frps
\`\`\`

### Mac 端

\`\`\`bash
# 启动 frpc
cd web-server
./frpc -c frpc.ini

# 后台运行
nohup ./frpc -c frpc.ini > logs/frpc.log 2>&1 &

# 停止 frpc
pkill frpc

# 查看日志
tail -f logs/frpc.log
\`\`\`

---

## 🐛 故障排除

### 问题 1：公网无法访问

**检查清单**：
- [ ] VPS frps 服务是否运行？\`sudo systemctl status frps\`
- [ ] 腾讯云安全组是否开放端口？（7000, 8080）
- [ ] Mac frpc 是否连接成功？查看日志
- [ ] 防火墙是否阻止？\`sudo ufw status\`

### 问题 2：frpc 连接失败

**错误**：\`connect to server failed\`

**解决**：
\`\`\`bash
# 1. 检查 VPS IP 是否正确
ping 193.112.94.2

# 2. 检查 VPS 端口是否开放
telnet 193.112.94.2 7000

# 3. 检查 Auth Token 是否一致
grep authentication_token vps-setup/frps.ini
grep authentication_token web-server/frpc.ini
\`\`\`

### 问题 3：Dashboard 无法访问

**检查**：
\`\`\`bash
# VPS 端检查端口
sudo ss -tuln | grep 7500

# 本地测试
curl http://193.112.94.2:7500
\`\`\`

---

## 📚 相关资源

- **frp 官方文档**：https://gofrp.org/docs/
- **GitHub 仓库**：https://github.com/fatedier/frp
- **腾讯云安全组**：https://console.cloud.tencent.com/cvm/securitygroup

---

**祝部署顺利！** 🚀
EOF

echo "✅ 部署说明已生成到 DEPLOY_INSTRUCTIONS.md"
echo ""

# ==================== 完成提示 ====================
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}✅ 配置完成！${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "${YELLOW}📋 下一步操作：${NC}"
echo ""
echo "1. 查看部署说明："
echo "   open vps-setup/DEPLOY_INSTRUCTIONS.md"
echo ""
echo "2. 上传配置到 VPS："
echo "   scp frps.ini root@193.112.94.2:/root/"
echo "   scp install-frps.sh root@193.112.94.2:/root/"
echo ""
echo "3. SSH 登录 VPS 并安装："
echo "   ssh root@193.112.94.2"
echo "   cd /root && chmod +x install-frps.sh"
echo "   sudo ./install-frps.sh"
echo ""
echo -e "${YELLOW}📊 配置信息：${NC}"
echo "   Dashboard: http://193.112.94.2:7500"
echo "   用户名: admin"
echo "   密码: ${DASHBOARD_PWD}"
echo ""
echo "   Web 访问: http://193.112.94.2:8080"
echo ""
echo -e "${RED}⚠️  重要：${NC}"
echo "   配置已保存到 web-server/.frp-config"
echo "   请妥善保管，不要提交到 Git！"
echo ""
echo -e "${GREEN}============================================================${NC}"
