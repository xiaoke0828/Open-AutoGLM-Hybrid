#!/bin/bash

# ================================
# AutoGLM Web + frp 停止脚本（Mac 端）
# ================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_SERVER_DIR="$PROJECT_ROOT/web-server"

cd "$WEB_SERVER_DIR"

echo "======================================"
echo "停止 AutoGLM Web 服务"
echo "======================================"
echo ""

# 停止 Web 服务
if [ -f ".web.pid" ]; then
    WEB_PID=$(cat .web.pid)
    echo "🛑 停止 Web 服务 (PID: $WEB_PID)..."

    if kill -0 $WEB_PID 2>/dev/null; then
        kill $WEB_PID
        sleep 2

        # 如果进程还在，强制杀死
        if kill -0 $WEB_PID 2>/dev/null; then
            kill -9 $WEB_PID
        fi

        echo "✅ Web 服务已停止"
    else
        echo "⚠️  Web 服务未运行"
    fi

    rm .web.pid
else
    echo "⚠️  未找到 Web 服务 PID 文件"
fi

# 停止 frp 客户端
if [ -f ".frpc.pid" ]; then
    FRP_PID=$(cat .frpc.pid)
    echo "🛑 停止 frp 客户端 (PID: $FRP_PID)..."

    if kill -0 $FRP_PID 2>/dev/null; then
        kill $FRP_PID
        sleep 1

        # 如果进程还在，强制杀死
        if kill -0 $FRP_PID 2>/dev/null; then
            kill -9 $FRP_PID
        fi

        echo "✅ frp 客户端已停止"
    else
        echo "⚠️  frp 客户端未运行"
    fi

    rm .frpc.pid
else
    echo "⚠️  未找到 frp 客户端 PID 文件"
fi

echo ""
echo "======================================"
echo "✅ 服务已停止"
echo "======================================"
echo ""
