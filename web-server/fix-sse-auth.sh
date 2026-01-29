#!/bin/bash

# ================================
# 修复 SSE 认证问题
# ================================

set -e

cd "$(dirname "$0")"

echo "======================================"
echo "修复 SSE 实时日志认证问题"
echo "======================================"
echo ""

echo "📝 备份 app.py..."
cp app.py app.py.backup-sse

echo "📝 修复 SSE 路由..."

# 使用 Python 脚本修复（更可靠）
python3 << 'PYTHONSCRIPT'
import re

with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 找到 SSE 路由，移除 @require_auth 装饰器
# 从：
# @app.route('/api/tasks/<task_id>/logs', methods=['GET'])
# @require_auth
# def get_task_logs_stream(task_id):
# 改为：
# @app.route('/api/tasks/<task_id>/logs', methods=['GET'])
# def get_task_logs_stream(task_id):

pattern = r"(@app\.route\('/api/tasks/<task_id>/logs',.*?\n)@require_auth\n(def get_task_logs_stream)"
replacement = r"\1\2"

new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

# 如果没有匹配到，尝试更宽松的模式
if new_content == content:
    pattern2 = r"(@app\.route\(['\"]\/api\/tasks\/<task_id>\/logs.*?\n)(\s*)@require_auth\n"
    replacement2 = r"\1\2"
    new_content = re.sub(pattern2, replacement2, content)

with open('app.py', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("✅ 已移除 SSE 日志接口的认证装饰器")
PYTHONSCRIPT

echo ""
echo "======================================"
echo "✅ 修复完成！"
echo "======================================"
echo ""
echo "现在重新启动服务："
echo "  按 Ctrl+C 停止当前服务"
echo "  然后运行: ./setup-and-start.sh"
echo ""
