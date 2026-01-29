#!/bin/bash

# Open-AutoGLM Mac 服务器部署脚本
# 版本: 1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印函数
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "============================================================"
    echo "  Open-AutoGLM Mac 服务器部署"
    echo "  版本: 1.0.0"
    echo "============================================================"
    echo ""
}

# 检查 macOS 版本
check_macos() {
    print_info "检查 macOS 版本..."
    os_version=$(sw_vers -productVersion)
    print_success "macOS 版本: $os_version"
}

# 检查并安装 Homebrew
check_homebrew() {
    print_info "检查 Homebrew..."
    if ! command -v brew &> /dev/null; then
        print_warning "Homebrew 未安装，正在安装..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        print_success "Homebrew 安装完成"
    else
        print_success "Homebrew 已安装: $(brew --version | head -n1)"
    fi
}

# 检查并安装 Python
check_python() {
    print_info "检查 Python..."
    if ! command -v python3 &> /dev/null; then
        print_warning "Python 3 未安装，正在安装..."
        brew install python@3.11
        print_success "Python 3 安装完成"
    else
        python_version=$(python3 --version)
        print_success "Python 已安装: $python_version"
    fi
}

# 创建虚拟环境
create_venv() {
    print_info "创建 Python 虚拟环境..."

    if [ -d "venv" ]; then
        print_warning "虚拟环境已存在，跳过创建"
    else
        python3 -m venv venv
        print_success "虚拟环境创建完成"
    fi

    # 激活虚拟环境
    source venv/bin/activate
    print_success "虚拟环境已激活"
}

# 安装 Python 依赖
install_python_packages() {
    print_info "安装 Python 依赖包..."

    # 确保虚拟环境激活
    source venv/bin/activate

    # 升级 pip
    pip install --upgrade pip

    # 安装依赖
    pip install pillow requests

    print_success "Python 依赖安装完成"
}

# 克隆 Open-AutoGLM
clone_autoglm() {
    print_info "下载 Open-AutoGLM..."

    if [ -d "Open-AutoGLM" ]; then
        print_warning "Open-AutoGLM 已存在，跳过下载"
        cd Open-AutoGLM
        git pull origin main || print_warning "更新失败，使用现有版本"
        cd ..
    else
        git clone https://github.com/zai-org/Open-AutoGLM.git
        print_success "Open-AutoGLM 下载完成"
    fi
}

# 智能检测手机 IP 地址
detect_phone_ip() {
    print_info "自动检测手机 IP 地址..."
    echo ""

    local detected_ip=""
    local detection_method=""

    # 方法1: 检测 Tailscale IP
    if command -v tailscale &> /dev/null; then
        print_info "检测到 Tailscale，正在查找设备..."

        # 获取 Tailscale 设备列表
        local tailscale_devices=$(tailscale status 2>/dev/null | grep -v "^#" | awk '{print $2, $1}')

        if [ ! -z "$tailscale_devices" ]; then
            echo "$tailscale_devices" | while read -r device_name device_ip; do
                # 跳过本机
                if echo "$device_name" | grep -qi "mac\|macbook"; then
                    continue
                fi

                # 检测 Android 设备
                if echo "$device_name" | grep -qi "android\|phone\|pixel\|xiaomi\|oppo\|vivo\|huawei"; then
                    print_info "发现 Tailscale 设备: $device_name ($device_ip)"

                    # 测试连接
                    if curl -s --max-time 3 "http://${device_ip}:8080/status" > /dev/null 2>&1; then
                        print_success "✅ 连接成功: $device_ip"
                        detected_ip="$device_ip"
                        detection_method="Tailscale"
                        break
                    else
                        print_warning "⚠️ 无法连接到 $device_ip:8080（可能是防火墙或 APP 未启动）"
                    fi
                fi
            done
        fi
    fi

    # 方法2: 检测局域网 IP（通过 ARP 表）
    if [ -z "$detected_ip" ]; then
        print_info "检测局域网设备..."

        # 获取 ARP 表中的 Android 设备
        local lan_devices=$(arp -a | grep -E '\([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\)' | awk '{print $2}' | tr -d '()')

        if [ ! -z "$lan_devices" ]; then
            echo "$lan_devices" | while read -r device_ip; do
                # 跳过本机和网关
                if echo "$device_ip" | grep -qE "^127\.|^169\.254\."; then
                    continue
                fi

                print_info "测试设备: $device_ip"

                # 测试连接
                if curl -s --max-time 2 "http://${device_ip}:8080/status" > /dev/null 2>&1; then
                    print_success "✅ 找到 AutoGLM Helper: $device_ip"
                    detected_ip="$device_ip"
                    detection_method="局域网 ARP"
                    break
                fi
            done
        fi
    fi

    # 方法3: 手动输入
    if [ -z "$detected_ip" ]; then
        print_warning "无法自动检测到手机，请手动输入"
        echo ""
        echo "获取手机 IP 的方法："
        echo "1. 如果使用 Tailscale: 在手机 Tailscale APP 中查看 IP（通常是 100.x.x.x）"
        echo "2. 如果使用局域网: 在手机的 WiFi 设置中查看 IP（通常是 192.168.x.x）"
        echo "3. 使用 ADB: adb shell ip addr show wlan0 | grep 'inet '"
        echo ""

        read -p "请输入手机 IP 地址 (例如: 192.168.1.100 或 100.64.0.2): " manual_ip

        # 验证 IP 格式
        if [[ $manual_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            # 测试连接
            print_info "测试连接: $manual_ip:8080"
            if curl -s --max-time 5 "http://${manual_ip}:8080/status" > /dev/null 2>&1; then
                print_success "✅ 连接成功"
                detected_ip="$manual_ip"
                detection_method="手动输入"
            else
                print_warning "⚠️ 无法连接到 $manual_ip:8080"
                print_info "将使用此 IP，但您可能需要稍后修改 config.env"
                detected_ip="$manual_ip"
                detection_method="手动输入（未验证）"
            fi
        else
            print_error "IP 格式无效，使用默认值 localhost"
            detected_ip="localhost"
            detection_method="默认"
        fi
    fi

    # 返回检测结果
    echo "$detected_ip|$detection_method"
}

# 创建配置文件
create_config() {
    print_info "创建配置文件..."
    echo ""

    # 智能检测手机 IP
    local ip_result=$(detect_phone_ip)
    local phone_ip=$(echo "$ip_result" | cut -d'|' -f1)
    local detection_method=$(echo "$ip_result" | cut -d'|' -f2)

    local phone_helper_url="http://${phone_ip}:8080"

    echo ""
    print_success "手机地址: $phone_helper_url（检测方式: $detection_method）"
    echo ""

    # 创建配置文件
    cat > config.env << EOF
# Open-AutoGLM Mac 服务器配置

# GRS AI API Key（必填）
export PHONE_AGENT_API_KEY="your_api_key_here"

# 手机 AutoGLM Helper 地址
# 自动检测结果: $phone_helper_url (检测方式: $detection_method)
export PHONE_HELPER_URL="$phone_helper_url"

# 日志级别
export LOG_LEVEL="INFO"
EOF

    print_success "配置文件已创建: config.env"
    print_warning "请编辑 config.env 填入您的 GRS AI API Key"

    # 如果无法连接，提示用户
    if echo "$detection_method" | grep -q "未验证"; then
        echo ""
        print_warning "未能验证手机连接，请确保："
        echo "  1. AutoGLM Helper APP 已在手机上运行"
        echo "  2. 无障碍服务已开启"
        echo "  3. 防火墙允许端口 8080 访问"
        echo ""
        print_info "您可以稍后修改配置文件中的 PHONE_HELPER_URL"
    fi
}

# 创建启动脚本
create_start_script() {
    print_info "创建启动脚本..."

    cat > start-server.sh << 'EOF'
#!/bin/bash

# Open-AutoGLM Mac 服务器启动脚本（增强版）
# 包含完整的前置检查和错误处理

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_error() {
    echo -e "${RED}[错误]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[成功]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[信息]${NC} $1"
}

# ============================================================
# 前置检查
# ============================================================

print_info "正在启动 Open-AutoGLM Mac 服务器..."
echo ""

# 检查1: 配置文件
if [ ! -f "config.env" ]; then
    print_error "配置文件不存在: config.env"
    echo ""
    echo "请先运行部署脚本："
    echo "  cd ~/autoglm-server"
    echo "  bash deploy-mac.sh"
    echo ""
    exit 1
fi

# 检查2: 加载配置
print_info "加载配置文件..."
source config.env

# 检查3: API Key
if [ "$PHONE_AGENT_API_KEY" = "your_api_key_here" ]; then
    print_error "API Key 未配置"
    echo ""
    echo "请编辑配置文件并填入您的 GRS AI API Key:"
    echo "  nano config.env"
    echo "  修改: export PHONE_AGENT_API_KEY='your_actual_key'"
    echo ""
    exit 1
fi

if [ -z "$PHONE_AGENT_API_KEY" ]; then
    print_error "API Key 为空"
    echo "请在 config.env 中配置有效的 API Key"
    exit 1
fi

# 检查4: PHONE_HELPER_URL
if [ -z "$PHONE_HELPER_URL" ]; then
    print_error "PHONE_HELPER_URL 未配置"
    echo "请在 config.env 中配置手机 IP 地址"
    exit 1
fi

# 检查5: 虚拟环境
if [ ! -d "venv" ]; then
    print_error "虚拟环境不存在"
    echo "请先运行部署脚本: bash deploy-mac.sh"
    exit 1
fi

# 检查6: Open-AutoGLM 目录
if [ ! -d "Open-AutoGLM" ]; then
    print_error "Open-AutoGLM 目录不存在"
    echo "请先运行部署脚本: bash deploy-mac.sh"
    exit 1
fi

# 检查7: 手机连接
print_info "测试手机连接: $PHONE_HELPER_URL"

if curl -s --max-time 5 "$PHONE_HELPER_URL/status" > /dev/null 2>&1; then
    status_json=$(curl -s "$PHONE_HELPER_URL/status")
    if echo "$status_json" | grep -q '"accessibility_enabled":true'; then
        print_success "手机已连接（无障碍模式）"
    else
        print_warning "手机已连接，但无障碍服务未开启"
        print_info "建议开启无障碍服务以获得最佳性能"
    fi
else
    print_warning "无法连接到手机: $PHONE_HELPER_URL"
    echo ""
    echo "⚠️  请确保："
    echo "  1. 手机上的 AutoGLM Helper APP 已运行"
    echo "  2. 无障碍服务已开启"
    echo "  3. 手机和 Mac 在同一网络（或通过 Tailscale 连接）"
    echo "  4. 防火墙允许端口 8080 访问"
    echo ""
    echo "提示: 系统也支持 LADB 备用模式，如果手机已配置 LADB 可继续运行"
    echo ""
    read -p "是否继续启动? (y/n): " confirm

    if [ "$confirm" != "y" ]; then
        print_info "已取消启动"
        exit 0
    fi
fi

echo ""
print_success "前置检查通过"
echo ""

# ============================================================
# 启动服务
# ============================================================

# 激活虚拟环境
source venv/bin/activate

print_info "启动 Open-AutoGLM..."
echo "配置信息:"
echo "  - 手机地址: $PHONE_HELPER_URL"
echo "  - API 基础 URL: ${PHONE_AGENT_BASE_URL:-默认}"
echo "  - 日志级别: ${LOG_LEVEL:-INFO}"
echo ""

cd Open-AutoGLM

# 捕获启动错误
if ! python main.py; then
    echo ""
    print_error "启动失败"
    echo ""
    echo "🔧 故障排除："
    echo "  1. 检查 API Key 是否正确"
    echo "     查看配置: cat ~/autoglm-server/config.env"
    echo ""
    echo "  2. 检查手机连接"
    echo "     测试命令: curl $PHONE_HELPER_URL/status"
    echo ""
    echo "  3. 查看详细错误信息"
    echo "     上面的错误输出包含了详细信息"
    echo ""
    echo "  4. 检查日志（如果有）"
    echo "     日志位置: ~/autoglm-server/Open-AutoGLM/logs/"
    echo ""
    echo "  5. 重新部署"
    echo "     命令: cd ~/autoglm-server && bash deploy-mac.sh"
    echo ""
    exit 1
fi
EOF

    chmod +x start-server.sh
    print_success "启动脚本已创建: start-server.sh"
    print_info "启动脚本位置: ~/autoglm-server/start-server.sh"
}

# 主函数
main() {
    print_header

    # 检查系统
    check_macos
    check_homebrew
    check_python

    # 创建工作目录
    print_info "创建工作目录..."
    mkdir -p ~/autoglm-server
    cd ~/autoglm-server

    # 设置环境
    create_venv
    install_python_packages
    clone_autoglm

    # 创建配置和脚本
    create_config
    create_start_script

    # 完成
    echo ""
    echo "============================================================"
    print_success "部署完成！"
    echo "============================================================"
    echo ""
    echo "下一步操作："
    echo "1. 编辑配置文件: nano ~/autoglm-server/config.env"
    echo "2. 填入您的 GRS AI API Key"
    echo "3. 填入手机的 IP 地址（局域网或 Tailscale IP）"
    echo "4. 启动服务: cd ~/autoglm-server && ./start-server.sh"
    echo ""
    echo "配置 Tailscale 远程访问，请参考文档: docs/TAILSCALE_GUIDE.md"
    echo ""
}

# 运行主函数
main
