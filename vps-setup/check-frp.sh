#!/bin/bash

# frp 公网访问快速诊断脚本

echo "==================================================="
echo "🔍 frp 公网访问诊断工具"
echo "==================================================="
echo ""

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查计数
PASS=0
FAIL=0

check_item() {
    local name="$1"
    local command="$2"

    echo -n "检查 $name... "
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 通过${NC}"
        ((PASS++))
        return 0
    else
        echo -e "${RED}❌ 失败${NC}"
        ((FAIL++))
        return 1
    fi
}

# 1. 检查本地 Web 服务器
check_item "本地 Web 服务器 (8000)" "curl -s --connect-timeout 2 http://127.0.0.1:8000"

# 2. 检查 frpc 进程
check_item "frpc 进程" "ps aux | grep '[f]rpc -c'"

# 3. 检查 VPS 网络
check_item "VPS 网络连通性" "ping -c 1 -W 2 193.112.94.2"

# 4. 检查 frp 服务端口
echo -n "检查 frp 服务端口 (7000)... "
if nc -zv -w 3 193.112.94.2 7000 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✅ 通过${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ 失败${NC}"
    ((FAIL++))
fi

# 5. 检查 Web 公网端口
echo -n "检查 Web 公网端口 (8080)... "
if nc -zv -w 3 193.112.94.2 8080 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✅ 通过${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ 失败${NC}"
    ((FAIL++))
fi

# 6. 检查 Dashboard
echo -n "检查 Dashboard (7500)... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 http://193.112.94.2:7500 2>/dev/null)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
    echo -e "${GREEN}✅ 通过${NC}"
    ((PASS++))
else
    echo -e "${RED}❌ 失败 (HTTP $HTTP_CODE)${NC}"
    ((FAIL++))
fi

echo ""
echo "==================================================="
echo "📊 检查结果汇总"
echo "==================================================="
echo -e "通过: ${GREEN}$PASS${NC} 项"
echo -e "失败: ${RED}$FAIL${NC} 项"
echo ""

# 诊断建议
if [ $FAIL -gt 0 ]; then
    echo -e "${YELLOW}💡 诊断建议：${NC}"
    echo ""

    # 检查本地服务
    if ! ps aux | grep '[p]ython app.py' > /dev/null; then
        echo "❌ Web 服务器未运行"
        echo "   解决: cd web-server && source venv/bin/activate && python app.py"
        echo ""
    fi

    if ! ps aux | grep '[f]rpc -c' > /dev/null; then
        echo "❌ frpc 未运行"
        echo "   解决: cd web-server && ./frpc -c frpc.ini"
        echo ""
    fi

    # 检查 VPS 端口
    if ! nc -zv -w 3 193.112.94.2 7000 2>&1 | grep -q succeeded; then
        echo "❌ VPS frp 端口 (7000) 不可达"
        echo "   可能原因:"
        echo "   1. VPS 上的 frps 未安装或未运行"
        echo "   2. 腾讯云安全组未开放 7000 端口"
        echo "   解决: 查看 TROUBLESHOOTING.md 步骤 1 和 2"
        echo ""
    fi

    if ! nc -zv -w 3 193.112.94.2 8080 2>&1 | grep -q succeeded; then
        echo "❌ VPS Web 端口 (8080) 不可达"
        echo "   可能原因:"
        echo "   1. 腾讯云安全组未开放 8080 端口"
        echo "   2. frpc 未成功建立隧道"
        echo "   解决: 查看 TROUBLESHOOTING.md 步骤 2 和 4"
        echo ""
    fi

    echo "📚 详细排查步骤请参考: vps-setup/TROUBLESHOOTING.md"
else
    echo -e "${GREEN}🎉 所有检查通过！${NC}"
    echo ""
    echo "您现在可以访问:"
    echo "  - Web 界面: http://193.112.94.2:8080"
    echo "  - Dashboard: http://193.112.94.2:7500"
fi

echo "==================================================="
