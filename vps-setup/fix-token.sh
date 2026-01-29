#!/bin/bash

# ================================
# VPS 端 Token 修复脚本
# ================================

set -e

TOKEN="7M4Ytwr04G8YGsrSsseqH32j00x5oMFi"

echo "======================================"
echo "修复 frps Token 配置"
echo "======================================"
echo ""

# 修改 Token
echo "📝 修改 authentication_token..."
sudo sed -i "s/authentication_token = .*/authentication_token = $TOKEN/" /usr/local/frp/frps.ini

# 验证修改
echo "✅ 验证配置..."
grep "authentication_token" /usr/local/frp/frps.ini
echo ""

# 重启服务
echo "🔄 重启 frps 服务..."
sudo systemctl restart frps

# 等待启动
sleep 3

# 检查状态
echo "📊 检查服务状态..."
sudo systemctl status frps --no-pager | head -15
echo ""

# 查看日志
echo "📋 最近日志..."
sudo tail -10 /var/log/frps.log
echo ""

echo "======================================"
echo "✅ VPS 端修复完成！"
echo "======================================"
echo ""
echo "Token: $TOKEN"
echo ""
