#!/bin/bash

# ================================
# 诊断任务提交问题
# ================================

cd "$(dirname "$0")"

echo "======================================"
echo "诊断任务提交问题"
echo "======================================"
echo ""

echo "【1. 检查配置文件】"
echo "=== .env 内容 ==="
cat .env
echo ""

echo "【2. 测试手机连接】"
PHONE_URL=$(grep PHONE_HELPER_URL .env | cut -d'=' -f2)
echo "配置的手机地址: $PHONE_URL"
echo "测试连接..."
curl -s "${PHONE_URL}/status" && echo "✅ 手机连接正常" || echo "❌ 手机无法连接"
echo ""

echo "【3. 最新错误日志（最后 50 行）】"
echo "=== app.log ==="
tail -50 ../logs/web/app.log
echo ""

echo "【4. 检查进程状态】"
ps aux | grep -E "python.*app.py" | grep -v grep || echo "⚠️  Web 服务未运行"
echo ""

echo "======================================"
echo "诊断完成"
echo "======================================"
