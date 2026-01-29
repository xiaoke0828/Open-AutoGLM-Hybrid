#!/bin/bash

# 快速重启 Flask 应用（保持 frpc 运行）

cd "$(dirname "$0")"

echo "🔄 快速重启 Flask 应用..."

# 1. 停止 Flask
pkill -f "python.*app.py"
sleep 2

# 2. 启动 Flask
source venv/bin/activate
source .env
nohup python app.py >> ../logs/web/app.log 2>&1 &
NEW_PID=$!

echo "✅ Flask 已重启 (PID: $NEW_PID)"
echo ""
echo "🌐 访问地址: http://193.112.94.2:8080"
echo "📋 查看日志: tail -f ../logs/web/app.log"
