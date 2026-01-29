#!/bin/bash

# 重启 Web 服务脚本

cd "$(dirname "$0")"

echo "========================================"
echo "重启 Open-AutoGLM Web 服务"
echo "========================================"
echo ""

# 1. 停止旧进程
echo "📍 停止旧服务进程..."
pkill -f "python.*app.py" || echo "没有找到运行中的服务"
pkill -f "frpc.*-c.*frpc.ini" || echo "没有找到运行中的 frpc"
sleep 2

# 2. 启动新服务
echo ""
echo "🚀 启动新服务..."
./setup-and-start.sh
