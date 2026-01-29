#!/bin/bash

# 重启 Web 服务器（AI 增强版）

echo "🔧 正在重启 Web 服务器..."

# 停止旧的进程
if [ -f .web.pid ]; then
    OLD_PID=$(cat .web.pid)
    if ps -p $OLD_PID > /dev/null 2>&1; then
        echo "停止旧的 Web 服务器 (PID: $OLD_PID)..."
        kill $OLD_PID
        sleep 2
    fi
    rm .web.pid
fi

# 检查配置
echo ""
echo "📝 检查配置..."
source .env

if [ -z "$PHONE_AGENT_API_KEY" ]; then
    echo "❌ 错误: PHONE_AGENT_API_KEY 未设置"
    echo "请在 .env 文件中配置您的 API Key"
    exit 1
fi

echo "✅ PHONE_HELPER_URL: $PHONE_HELPER_URL"
echo "✅ PHONE_AGENT_API_KEY: ${PHONE_AGENT_API_KEY:0:20}..."
echo "✅ PHONE_AGENT_BASE_URL: ${PHONE_AGENT_BASE_URL:-https://api.grsai.com/v1}"
echo "✅ PHONE_AGENT_MODEL: ${PHONE_AGENT_MODEL:-gpt-4-vision-preview}"

# 测试手机连接
echo ""
echo "📱 测试手机连接..."
if curl -s --max-time 3 "$PHONE_HELPER_URL/status" > /dev/null 2>&1; then
    echo "✅ 手机连接正常"
else
    echo "⚠️  警告: 无法连接到手机 ($PHONE_HELPER_URL)"
    echo "请确保:"
    echo "  1. AutoGLM Helper APP 已运行"
    echo "  2. 无障碍服务已开启"
    echo "  3. 手机 IP 地址正确"
    echo ""
    read -p "是否继续启动? (y/n): " confirm
    if [ "$confirm" != "y" ]; then
        exit 0
    fi
fi

# 激活虚拟环境（如果存在）
if [ -d "venv" ]; then
    echo ""
    echo "激活虚拟环境..."
    source venv/bin/activate
fi

# 安装 openai 依赖（如果缺少）
echo ""
echo "检查依赖..."
if ! python3 -c "import openai" 2>/dev/null; then
    echo "安装 openai 库..."
    pip3 install openai
fi

# 启动服务器
echo ""
echo "🚀 启动 Web 服务器（AI 增强版）..."
nohup python3 app.py > logs/web-ai.log 2>&1 &
WEB_PID=$!
echo $WEB_PID > .web.pid

echo ""
echo "✅ Web 服务器已启动！"
echo "   - PID: $WEB_PID"
echo "   - URL: http://${WEB_HOST:-127.0.0.1}:${WEB_PORT:-5000}"
echo "   - 日志: logs/web-ai.log"
echo ""
echo "查看日志："
echo "  tail -f logs/web-ai.log"
echo ""
echo "停止服务器："
echo "  kill $WEB_PID"
echo ""

# 等待启动
sleep 2

# 查看最新日志
echo "📋 最新日志:"
tail -20 logs/web-ai.log
