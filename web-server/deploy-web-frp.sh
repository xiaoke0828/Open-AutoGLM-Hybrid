#!/bin/bash

# ================================
# AutoGLM Web + frp 一键部署脚本（Mac 端）
# ================================

set -e

echo "======================================"
echo "AutoGLM Web + frp 一键部署"
echo "======================================"
echo ""

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_SERVER_DIR="$PROJECT_ROOT/web-server"

cd "$WEB_SERVER_DIR"

# 步骤 1: 检查 Python
echo "📦 步骤 1/7: 检查 Python 环境..."
if ! command -v python3 &> /dev/null; then
    echo "❌ 未找到 Python 3，请先安装"
    exit 1
fi
PYTHON_VERSION=$(python3 --version)
echo "✅ 找到 $PYTHON_VERSION"
echo ""

# 步骤 2: 创建虚拟环境
echo "🐍 步骤 2/7: 创建 Python 虚拟环境..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "✅ 虚拟环境已创建"
else
    echo "✅ 虚拟环境已存在"
fi
echo ""

# 步骤 3: 安装依赖
echo "📦 步骤 3/7: 安装 Python 依赖..."
source venv/bin/activate
pip install --upgrade pip > /dev/null
pip install -r requirements.txt
echo "✅ 依赖安装完成"
echo ""

# 步骤 4: 下载 frp
echo "📥 步骤 4/7: 下载 frp 客户端..."
FRP_VERSION="0.55.1"
FRP_FILE="frp_${FRP_VERSION}_darwin_amd64"

# 检测 Mac 架构
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    FRP_FILE="frp_${FRP_VERSION}_darwin_arm64"
fi

FRP_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FRP_FILE}.tar.gz"

if [ ! -f "frpc" ]; then
    echo "   下载 frp v${FRP_VERSION} ($ARCH)..."
    cd /tmp
    if [ ! -f "${FRP_FILE}.tar.gz" ]; then
        curl -LO "$FRP_URL" || {
            echo "❌ 下载失败，请检查网络或手动下载: $FRP_URL"
            exit 1
        }
    fi

    tar -xzf "${FRP_FILE}.tar.gz"
    cp "${FRP_FILE}/frpc" "$WEB_SERVER_DIR/"
    chmod +x "$WEB_SERVER_DIR/frpc"
    echo "✅ frp 客户端已安装"
else
    echo "✅ frp 客户端已存在"
fi
cd "$WEB_SERVER_DIR"
echo ""

# 步骤 5: 配置 frp
echo "⚙️  步骤 5/7: 配置 frp 客户端..."
if [ ! -f "frpc.ini.local" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "请输入你的 VPS 配置信息："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    read -p "VPS IP 地址: " VPS_IP
    read -p "frp 认证 Token（与 VPS 端一致）: " AUTH_TOKEN

    # 生成配置文件
    cat > frpc.ini.local << EOF
[common]
server_addr = $VPS_IP
server_port = 7000
authentication_token = $AUTH_TOKEN
user = mac_autoglm
log_file = ../logs/frpc.log
log_level = info
log_max_days = 7
heartbeat_interval = 30
heartbeat_timeout = 90
pool_count = 5

[web]
type = tcp
local_ip = 127.0.0.1
local_port = 5000
remote_port = 8080
EOF

    echo "✅ frp 配置已保存到 frpc.ini.local"
else
    echo "✅ frp 配置已存在 (frpc.ini.local)"
fi
echo ""

# 步骤 6: 配置环境变量
echo "🔧 步骤 6/7: 配置环境变量..."
if [ ! -f ".env" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "请输入 Open-AutoGLM 配置信息："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    read -p "手机 IP 地址（AutoGLM Helper）: " PHONE_IP
    read -p "GRS AI API Key: " API_KEY

    # 生成 .env 文件
    cat > .env << EOF
# Web 服务配置
WEB_HOST=127.0.0.1
WEB_PORT=5000

# 手机控制器配置
PHONE_HELPER_URL=http://$PHONE_IP:8080
PHONE_AGENT_API_KEY=$API_KEY
EOF

    echo "✅ 环境变量已保存到 .env"
else
    echo "✅ 环境变量已存在 (.env)"
fi
echo ""

# 步骤 7: 创建日志目录
echo "📁 步骤 7/7: 创建日志目录..."
mkdir -p ../logs
echo "✅ 日志目录已创建"
echo ""

# 完成
echo "======================================"
echo "✅ 部署完成！"
echo "======================================"
echo ""
echo "📝 下一步操作："
echo "   1. 确保你的 VPS 上已部署并启动 frps"
echo "   2. 确保手机上的 AutoGLM Helper 已启动"
echo "   3. 运行启动脚本："
echo ""
echo "      cd $WEB_SERVER_DIR"
echo "      ./start-web-frp.sh"
echo ""
echo "   4. 访问 Web 界面："
echo "      - 本地: http://localhost:5000"
echo "      - 公网: http://你的VPS_IP:8080"
echo ""
echo "📋 配置文件位置："
echo "   - frp 配置: $WEB_SERVER_DIR/frpc.ini.local"
echo "   - 环境变量: $WEB_SERVER_DIR/.env"
echo "   - 认证 Token: $WEB_SERVER_DIR/.auth_token（首次运行时自动生成）"
echo ""
echo "🔧 常用命令："
echo "   启动服务: ./start-web-frp.sh"
echo "   停止服务: ./stop-web-frp.sh"
echo "   查看日志: tail -f ../logs/web/app.log"
echo ""
