#!/bin/bash

# ================================
# AutoGLM Web + frp 启动脚本（Mac 端）
# ================================

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_SERVER_DIR="$PROJECT_ROOT/web-server"

cd "$WEB_SERVER_DIR"

echo "======================================"
echo "启动 AutoGLM Web 服务"
echo "======================================"
echo ""

# 加载环境变量
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo "✅ 环境变量已加载"
else
    echo "⚠️  警告: 未找到 .env 文件，请先运行 deploy-web-frp.sh"
fi

# 检查 frp 配置
if [ ! -f "frpc.ini.local" ]; then
    echo "❌ 错误: 未找到 frp 配置文件 frpc.ini.local"
    echo "   请先运行: ./deploy-web-frp.sh"
    exit 1
fi

# 创建日志目录
mkdir -p ../logs

# 启动 frp 客户端
echo "🚀 启动 frp 客户端..."
if [ -f "frpc" ]; then
    ./frpc -c frpc.ini.local > /dev/null 2>&1 &
    FRP_PID=$!
    echo $FRP_PID > .frpc.pid
    echo "✅ frp 客户端已启动 (PID: $FRP_PID)"
    sleep 2

    # 检查 frp 是否正常运行
    if ! kill -0 $FRP_PID 2>/dev/null; then
        echo "❌ frp 客户端启动失败，请检查配置"
        echo "   查看日志: tail -f ../logs/frpc.log"
        exit 1
    fi
else
    echo "❌ 错误: 未找到 frpc 可执行文件"
    echo "   请先运行: ./deploy-web-frp.sh"
    exit 1
fi

# 激活虚拟环境
echo "🐍 激活 Python 虚拟环境..."
if [ -d "venv" ]; then
    source venv/bin/activate
    echo "✅ 虚拟环境已激活"
else
    echo "❌ 错误: 未找到虚拟环境"
    echo "   请先运行: ./deploy-web-frp.sh"
    exit 1
fi

# 启动 Web 服务
echo "🌐 启动 Web 服务..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
python app.py &
WEB_PID=$!
echo $WEB_PID > .web.pid
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 等待启动
sleep 3

# 检查服务状态
if ! kill -0 $WEB_PID 2>/dev/null; then
    echo "❌ Web 服务启动失败"
    echo "   查看日志: tail -f ../logs/web/app.log"
    ./stop-web-frp.sh
    exit 1
fi

echo "======================================"
echo "✅ 服务启动成功！"
echo "======================================"
echo ""
echo "📊 服务状态："
echo "   frp 客户端: 运行中 (PID: $FRP_PID)"
echo "   Web 服务: 运行中 (PID: $WEB_PID)"
echo ""
echo "🌐 访问地址："
VPS_IP=$(grep 'server_addr' frpc.ini.local | awk '{print $3}')
if [ -n "$VPS_IP" ]; then
    echo "   公网: http://$VPS_IP:8080"
fi
echo "   本地: http://localhost:5000"
echo ""
echo "🔑 认证 Token："
if [ -f ".auth_token" ]; then
    AUTH_TOKEN=$(cat .auth_token)
    echo "   $AUTH_TOKEN"
    echo "   (保存此 Token，用于 Web 界面登录)"
else
    echo "   首次运行时自动生成，请查看启动日志"
fi
echo ""
echo "📋 常用命令："
echo "   停止服务: ./stop-web-frp.sh"
echo "   查看日志: tail -f ../logs/web/app.log"
echo "   查看 frp 日志: tail -f ../logs/frpc.log"
echo ""
echo "⚠️  提示："
echo "   1. 请保持此终端窗口打开"
echo "   2. 按 Ctrl+C 可停止服务"
echo "   3. 或者在新终端运行: ./stop-web-frp.sh"
echo ""

# 等待用户中断
trap './stop-web-frp.sh; exit' INT TERM

# 跟踪日志
tail -f ../logs/web/app.log
