#!/bin/bash

# ================================
# Mac 端完整部署和启动脚本
# ================================

set -e

TOKEN="7M4Ytwr04G8YGsrSsseqH32j00x5oMFi"
VPS_IP="193.112.94.2"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_SERVER_DIR="$PROJECT_ROOT/web-server"

cd "$WEB_SERVER_DIR"

echo "======================================"
echo "Mac 端完整部署和启动"
echo "======================================"
echo ""

# 步骤 1: 停止旧服务
echo "🛑 步骤 1/8: 停止旧服务..."
./stop-web-frp.sh 2>/dev/null || true
sleep 2
echo "✅ 已停止"
echo ""

# 步骤 2: 创建虚拟环境
echo "🐍 步骤 2/8: 检查虚拟环境..."
if [ ! -d "venv" ]; then
    echo "   创建虚拟环境..."
    python3 -m venv venv
    echo "✅ 虚拟环境已创建"
else
    echo "✅ 虚拟环境已存在"
fi
echo ""

# 步骤 3: 安装依赖
echo "📦 步骤 3/8: 安装依赖..."
source venv/bin/activate
pip install --upgrade pip > /dev/null 2>&1
pip install -r requirements.txt
echo "✅ 依赖已安装"
echo ""

# 步骤 4: 创建 frpc 配置
echo "⚙️  步骤 4/8: 创建 frpc 配置..."
cat > frpc.ini.local << EOF
[common]
server_addr = $VPS_IP
server_port = 7000
authentication_token = $TOKEN
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
echo "✅ frpc 配置已创建"
echo ""

# 步骤 5: 创建 .env 配置
echo "🔧 步骤 5/8: 创建环境变量配置..."
if [ ! -f ".env" ]; then
    cat > .env << 'EOF'
WEB_HOST=127.0.0.1
WEB_PORT=5000
PHONE_HELPER_URL=http://192.168.1.100:8080
PHONE_AGENT_API_KEY=sk-test-placeholder
EOF
    echo "✅ .env 已创建（占位符，稍后可修改）"
else
    echo "✅ .env 已存在"
fi
echo ""

# 步骤 6: 下载 frpc
echo "📥 步骤 6/8: 检查 frpc 客户端..."
if [ ! -f "frpc" ]; then
    echo "   正在下载 frpc..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        FRP_FILE="frp_0.55.1_darwin_arm64"
    else
        FRP_FILE="frp_0.55.1_darwin_amd64"
    fi

    FRP_URL="https://github.com/fatedier/frp/releases/download/v0.55.1/${FRP_FILE}.tar.gz"

    cd /tmp
    curl -LO "$FRP_URL" || {
        echo "❌ 下载失败，请检查网络"
        exit 1
    }
    tar -xzf "${FRP_FILE}.tar.gz"
    cp "${FRP_FILE}/frpc" "$WEB_SERVER_DIR/"
    chmod +x "$WEB_SERVER_DIR/frpc"
    cd "$WEB_SERVER_DIR"
    echo "✅ frpc 已下载"
else
    echo "✅ frpc 已存在"
fi
echo ""

# 步骤 7: 创建日志目录
echo "📁 步骤 7/8: 创建日志目录..."
mkdir -p ../logs/web
echo "✅ 日志目录已创建"
echo ""

# 步骤 8: 启动服务
echo "🚀 步骤 8/8: 启动服务..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 启动 frpc
echo "🌐 启动 frp 客户端..."
./frpc -c frpc.ini.local > /dev/null 2>&1 &
FRP_PID=$!
echo $FRP_PID > .frpc.pid
echo "✅ frp 客户端已启动 (PID: $FRP_PID)"

# 等待连接
sleep 3

# 检查 frpc 是否正常运行
if ! kill -0 $FRP_PID 2>/dev/null; then
    echo "❌ frp 客户端启动失败，查看日志:"
    tail -20 ../logs/frpc.log
    exit 1
fi

# 检查连接状态
echo "🔍 检查连接状态..."
sleep 2
if grep -q "login to server success" ../logs/frpc.log; then
    echo "✅ frp 连接成功"
else
    echo "⚠️  frp 可能未连接成功，查看日志:"
    tail -10 ../logs/frpc.log
fi
echo ""

# 启动 Web 服务
echo "🌐 启动 Web 服务..."
source venv/bin/activate
export $(cat .env | grep -v '^#' | xargs)

python app.py &
WEB_PID=$!
echo $WEB_PID > .web.pid

# 等待启动
sleep 3

# 检查 Web 服务是否正常运行
if ! kill -0 $WEB_PID 2>/dev/null; then
    echo "❌ Web 服务启动失败，查看日志:"
    tail -20 ../logs/web/app.log
    ./stop-web-frp.sh
    exit 1
fi

echo "✅ Web 服务已启动 (PID: $WEB_PID)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 等待 Web 服务完全启动
sleep 3

# 显示认证 Token
echo "======================================"
echo "✅ 部署和启动完成！"
echo "======================================"
echo ""
echo "📊 服务状态："
echo "   frp 客户端: 运行中 (PID: $FRP_PID)"
echo "   Web 服务: 运行中 (PID: $WEB_PID)"
echo ""
echo "🌐 访问地址："
echo "   公网: http://$VPS_IP:8080"
echo "   本地: http://localhost:5000"
echo ""
echo "🔑 认证 Token："
if [ -f ".auth_token" ]; then
    AUTH_TOKEN=$(cat .auth_token)
    echo "   $AUTH_TOKEN"
    echo "   (保存此 Token，用于 Web 界面登录)"
else
    echo "   首次运行时自动生成，请查看上方启动日志"
fi
echo ""
echo "📋 常用命令："
echo "   停止服务: ./stop-web-frp.sh"
echo "   查看日志: tail -f ../logs/web/app.log"
echo "   查看 frp 日志: tail -f ../logs/frpc.log"
echo ""
echo "🔧 配置文件："
echo "   frp 配置: frpc.ini.local"
echo "   环境变量: .env"
echo ""

# 显示 frpc 日志
echo "📋 frpc 连接日志（最后 5 行）："
tail -5 ../logs/frpc.log
echo ""

echo "⚠️  提示："
echo "   1. 请保持此终端窗口打开"
echo "   2. 按 Ctrl+C 可停止服务"
echo "   3. 或者在新终端运行: ./stop-web-frp.sh"
echo ""

# 跟踪日志
echo "======================================"
echo "实时日志（按 Ctrl+C 停止）"
echo "======================================"
echo ""

trap './stop-web-frp.sh; exit' INT TERM

tail -f ../logs/web/app.log
