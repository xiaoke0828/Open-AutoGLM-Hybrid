#!/bin/bash

# ================================
# frp 服务端一键部署脚本（腾讯云 VPS）
# ================================

set -e

echo "======================================"
echo "frp 服务端一键部署脚本"
echo "======================================"
echo ""

# 检测系统架构
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    FRP_ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    FRP_ARCH="arm64"
else
    echo "❌ 不支持的系统架构: $ARCH"
    exit 1
fi

# frp 版本
FRP_VERSION="0.55.1"
FRP_FILE="frp_${FRP_VERSION}_linux_${FRP_ARCH}"
FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FRP_FILE}.tar.gz"

echo "📦 检测系统架构: $ARCH (frp: $FRP_ARCH)"
echo ""

# 步骤 1: 下载 frp
echo "📥 步骤 1/6: 下载 frp v${FRP_VERSION}..."
cd /tmp
if [ -f "${FRP_FILE}.tar.gz" ]; then
    echo "   文件已存在，跳过下载"
else
    wget -O "${FRP_FILE}.tar.gz" "$FRP_URL" || {
        echo "❌ 下载失败，请检查网络或手动下载: $FRP_URL"
        exit 1
    }
fi
echo "✅ 下载完成"
echo ""

# 步骤 2: 解压并安装
echo "📦 步骤 2/6: 解压并安装..."
tar -xzf "${FRP_FILE}.tar.gz"
cd "$FRP_FILE"
sudo mkdir -p /usr/local/frp
sudo cp frps /usr/local/frp/
sudo chmod +x /usr/local/frp/frps
echo "✅ 安装完成"
echo ""

# 步骤 3: 复制配置文件
echo "⚙️  步骤 3/6: 配置 frps..."
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -f "$SCRIPT_DIR/frps.ini" ]; then
    sudo cp "$SCRIPT_DIR/frps.ini" /usr/local/frp/
    echo "✅ 配置文件已复制"
else
    echo "⚠️  警告: 未找到 frps.ini，使用默认配置"
    cat > /tmp/frps.ini << 'EOF'
[common]
bind_port = 7000
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin123
authentication_token = change_me_token
log_file = /var/log/frps.log
log_level = info
log_max_days = 7
max_pool_count = 50
heartbeat_timeout = 90
allow_ports = 8080-8090
EOF
    sudo mv /tmp/frps.ini /usr/local/frp/
fi
echo ""

# 步骤 4: 创建 systemd 服务
echo "🔧 步骤 4/6: 创建 systemd 服务..."
sudo tee /etc/systemd/system/frps.service > /dev/null << EOF
[Unit]
Description=frp server
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/frp/frps -c /usr/local/frp/frps.ini
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
echo "✅ systemd 服务已创建"
echo ""

# 步骤 5: 配置防火墙
echo "🔥 步骤 5/6: 配置防火墙..."
if command -v firewall-cmd &> /dev/null; then
    echo "   检测到 firewalld..."
    sudo firewall-cmd --permanent --add-port=7000/tcp
    sudo firewall-cmd --permanent --add-port=7500/tcp
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
    echo "✅ firewalld 配置完成"
elif command -v ufw &> /dev/null; then
    echo "   检测到 ufw..."
    sudo ufw allow 7000/tcp
    sudo ufw allow 7500/tcp
    sudo ufw allow 8080/tcp
    echo "✅ ufw 配置完成"
else
    echo "⚠️  未检测到防火墙管理工具"
fi
echo ""
echo "⚠️  重要: 请在腾讯云控制台的安全组中开放以下端口："
echo "   - 7000 (frp 服务端口)"
echo "   - 7500 (Dashboard 端口，可选)"
echo "   - 8080 (Web 界面端口)"
echo ""

# 步骤 6: 启动服务
echo "🚀 步骤 6/6: 启动 frps 服务..."
sudo systemctl daemon-reload
sudo systemctl enable frps
sudo systemctl start frps
sleep 2
if sudo systemctl is-active --quiet frps; then
    echo "✅ frps 服务启动成功"
else
    echo "❌ frps 服务启动失败，查看日志:"
    sudo journalctl -u frps -n 20
    exit 1
fi
echo ""

# 显示状态
echo "======================================"
echo "✅ 部署完成！"
echo "======================================"
echo ""
echo "📊 服务状态:"
sudo systemctl status frps --no-pager | head -n 10
echo ""
echo "📝 常用命令:"
echo "   查看状态: sudo systemctl status frps"
echo "   查看日志: sudo tail -f /var/log/frps.log"
echo "   重启服务: sudo systemctl restart frps"
echo "   停止服务: sudo systemctl stop frps"
echo ""
echo "🌐 Dashboard 访问:"
echo "   地址: http://$(curl -s ifconfig.me):7500"
echo "   用户名: admin"
echo "   密码: 请查看 /usr/local/frp/frps.ini"
echo ""
echo "⚠️  重要提示:"
echo "   1. 请修改 /usr/local/frp/frps.ini 中的认证 token"
echo "   2. 请在腾讯云控制台开放安全组端口 7000、7500、8080"
echo "   3. 客户端配置时需要使用相同的 token"
echo ""
