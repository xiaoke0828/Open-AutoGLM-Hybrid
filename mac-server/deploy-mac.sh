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

# 创建配置文件
create_config() {
    print_info "创建配置文件..."

    cat > config.env << 'EOF'
# Open-AutoGLM Mac 服务器配置

# GRS AI API Key（必填）
export PHONE_AGENT_API_KEY="your_api_key_here"

# 手机 AutoGLM Helper 地址（修改为您的手机 IP）
# 局域网示例: http://192.168.1.100:8080
# Tailscale 示例: http://100.64.0.2:8080
export PHONE_HELPER_URL="http://localhost:8080"

# 日志级别
export LOG_LEVEL="INFO"
EOF

    print_success "配置文件已创建: config.env"
    print_warning "请编辑 config.env 填入您的 API Key 和手机 IP 地址"
}

# 创建启动脚本
create_start_script() {
    print_info "创建启动脚本..."

    cat > start-server.sh << 'EOF'
#!/bin/bash

# 加载配置
if [ -f "config.env" ]; then
    source config.env
else
    echo "错误: config.env 不存在，请先运行 deploy-mac.sh"
    exit 1
fi

# 检查 API Key
if [ "$PHONE_AGENT_API_KEY" = "your_api_key_here" ]; then
    echo "错误: 请先在 config.env 中配置您的 API Key"
    exit 1
fi

# 激活虚拟环境
source venv/bin/activate

# 启动服务
echo "正在启动 Open-AutoGLM Mac 服务器..."
echo "手机地址: $PHONE_HELPER_URL"
echo ""

cd Open-AutoGLM
python main.py
EOF

    chmod +x start-server.sh
    print_success "启动脚本已创建: start-server.sh"
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
