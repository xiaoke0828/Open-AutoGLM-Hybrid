#!/data/data/com.termux/files/usr/bin/bash

# Open-AutoGLM 混合方案 - Termux 一键部署脚本
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
    echo "  Open-AutoGLM 混合方案 - 一键部署"
    echo "  版本: 1.0.0"
    echo "============================================================"
    echo ""
}

# 检查网络连接
check_network() {
    print_info "检查网络连接..."
    if ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "网络连接正常"
    else
        print_error "网络连接失败，请检查网络设置"
        exit 1
    fi
}

# 更新软件包
update_packages() {
    print_info "更新软件包列表..."
    pkg update -y
    print_success "软件包列表更新完成"
}

# 安装必要软件
install_dependencies() {
    print_info "安装必要软件..."
    
    # 检查并安装 Python
    if ! command -v python &> /dev/null; then
        print_info "安装 Python..."
        pkg install python -y
    else
        print_success "Python 已安装: $(python --version)"
    fi
    
    # 检查并安装 Git
    if ! command -v git &> /dev/null; then
        print_info "安装 Git..."
        pkg install git -y
    else
        print_success "Git 已安装: $(git --version)"
    fi
    
    # 安装其他工具
    pkg install curl wget -y
    
    print_success "必要软件安装完成"
}

# 安装 Python 依赖
install_python_packages() {
    print_info "安装 Python 依赖包..."
    
    # 升级 pip
    pip install --upgrade pip
    
    # 安装依赖
    pip install pillow openai requests
    
    print_success "Python 依赖安装完成"
}

# 下载 Open-AutoGLM
download_autoglm() {
    print_info "下载 Open-AutoGLM 项目..."
    
    cd ~
    
    if [ -d "Open-AutoGLM" ]; then
        print_warning "Open-AutoGLM 目录已存在"
        read -p "是否删除并重新下载? (y/n): " confirm
        if [ "$confirm" = "y" ]; then
            rm -rf Open-AutoGLM
        else
            print_info "跳过下载，使用现有目录"
            return
        fi
    fi
    
    git clone https://github.com/zai-org/Open-AutoGLM.git
    
    print_success "Open-AutoGLM 下载完成"
}

# 安装 Open-AutoGLM
install_autoglm() {
    print_info "安装 Open-AutoGLM..."
    
    cd ~/Open-AutoGLM
    
    # 安装项目依赖
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    fi
    
    # 安装 phone_agent
    pip install -e .
    
    print_success "Open-AutoGLM 安装完成"
}

# 下载混合方案脚本
download_hybrid_scripts() {
    print_info "下载混合方案脚本..."
    
    cd ~
    
    # 创建目录
    mkdir -p ~/.autoglm
    
    # 创建 phone_controller.py (完整的自动降级控制器)
    cat > ~/.autoglm/phone_controller.py << 'PYTHON_EOF'
"""
Open-AutoGLM 混合方案 - 手机控制器（自动降级逻辑）
版本: 1.0.0

支持两种控制模式:
1. 无障碍服务模式 (优先) - 通过 AutoGLM Helper APP
2. LADB 模式 (备用) - 通过 ADB 连接

自动检测可用模式并降级
"""

import os
import subprocess
import requests
import base64
import time
import logging
from typing import Optional, Tuple
from PIL import Image
from io import BytesIO

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('PhoneController')


class PhoneController:
    """手机控制器 - 支持自动降级"""

    # 控制模式
    MODE_ACCESSIBILITY = "accessibility"  # 无障碍服务模式
    MODE_LADB = "ladb"  # LADB 模式
    MODE_NONE = "none"  # 无可用模式

    def __init__(self, helper_url: str = "http://localhost:8080"):
        """
        初始化手机控制器

        Args:
            helper_url: AutoGLM Helper 的 URL
        """
        self.helper_url = helper_url
        self.mode = self.MODE_NONE
        self.adb_device = None

        # 自动检测可用模式
        self._detect_mode()

    def _detect_mode(self):
        """检测可用的控制模式"""
        logger.info("检测可用的控制模式...")

        # 1. 尝试无障碍服务模式
        if self._try_accessibility_service():
            self.mode = self.MODE_ACCESSIBILITY
            logger.info(f"✅ 使用无障碍服务模式 ({self.helper_url})")
            return

        # 2. 降级到 LADB 模式
        if self._try_ladb():
            self.mode = self.MODE_LADB
            logger.warning(f"⚠️ 降级到 LADB 模式 (设备: {self.adb_device})")
            return

        # 3. 都不可用
        self.mode = self.MODE_NONE
        logger.error("❌ 无可用控制方式")
        raise Exception(
            "无法连接到手机控制服务！\n"
            "请确保:\n"
            "1. AutoGLM Helper 已运行并开启无障碍权限\n"
            "2. 或者 LADB 已配对并运行\n"
        )

    def _try_accessibility_service(self) -> bool:
        """尝试连接无障碍服务"""
        try:
            response = requests.get(
                f"{self.helper_url}/status",
                timeout=3
            )

            if response.status_code == 200:
                data = response.json()
                if data.get('accessibility_enabled'):
                    return True
                else:
                    logger.warning("AutoGLM Helper 运行中，但无障碍服务未开启")
                    return False

            return False
        except Exception as e:
            logger.debug(f"无障碍服务连接失败: {e}")
            return False

    def _try_ladb(self) -> bool:
        """尝试连接 LADB"""
        try:
            # 检查 adb 是否可用
            result = subprocess.run(
                ['adb', 'devices'],
                capture_output=True,
                text=True,
                timeout=3
            )

            if result.returncode != 0:
                logger.debug("ADB 命令不可用")
                return False

            # 解析设备列表
            lines = result.stdout.strip().split('\n')[1:]  # 跳过标题行
            devices = [line.split('\t')[0] for line in lines if '\tdevice' in line]

            if not devices:
                logger.debug("未找到已连接的 ADB 设备")
                return False

            # 使用第一个设备
            self.adb_device = devices[0]
            logger.info(f"找到 ADB 设备: {self.adb_device}")

            # 测试连接
            test_result = subprocess.run(
                ['adb', '-s', self.adb_device, 'shell', 'echo', 'test'],
                capture_output=True,
                timeout=3
            )

            return test_result.returncode == 0

        except Exception as e:
            logger.debug(f"LADB 连接失败: {e}")
            return False

    def get_mode(self) -> str:
        """获取当前控制模式"""
        return self.mode

    def screenshot(self) -> Optional[Image.Image]:
        """
        截取屏幕

        Returns:
            PIL.Image 对象，失败返回 None
        """
        if self.mode == self.MODE_ACCESSIBILITY:
            return self._screenshot_accessibility()
        elif self.mode == self.MODE_LADB:
            return self._screenshot_ladb()
        else:
            logger.error("无可用的截图方式")
            return None

    def _screenshot_accessibility(self) -> Optional[Image.Image]:
        """通过无障碍服务截图"""
        try:
            response = requests.get(
                f"{self.helper_url}/screenshot",
                timeout=10
            )

            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    # 解码 Base64 图片
                    image_data = base64.b64decode(data['image'])
                    image = Image.open(BytesIO(image_data))
                    logger.debug(f"截图成功 (无障碍): {image.size}")
                    return image

            logger.error(f"截图失败: HTTP {response.status_code}")
            return None

        except Exception as e:
            logger.error(f"截图失败 (无障碍): {e}")
            return None

    def _screenshot_ladb(self) -> Optional[Image.Image]:
        """通过 LADB 截图"""
        try:
            # 截图到设备
            subprocess.run(
                ['adb', '-s', self.adb_device, 'shell', 'screencap', '-p', '/sdcard/autoglm_screenshot.png'],
                check=True,
                timeout=5
            )

            # 拉取到本地
            local_path = '/tmp/autoglm_screenshot.png'
            subprocess.run(
                ['adb', '-s', self.adb_device, 'pull', '/sdcard/autoglm_screenshot.png', local_path],
                check=True,
                timeout=5
            )

            # 打开图片
            image = Image.open(local_path)
            logger.debug(f"截图成功 (LADB): {image.size}")

            # 清理临时文件
            subprocess.run(
                ['adb', '-s', self.adb_device, 'shell', 'rm', '/sdcard/autoglm_screenshot.png'],
                timeout=3
            )

            return image

        except Exception as e:
            logger.error(f"截图失败 (LADB): {e}")
            return None

    def tap(self, x: int, y: int) -> bool:
        """
        执行点击操作

        Args:
            x: X 坐标
            y: Y 坐标

        Returns:
            是否成功
        """
        if self.mode == self.MODE_ACCESSIBILITY:
            return self._tap_accessibility(x, y)
        elif self.mode == self.MODE_LADB:
            return self._tap_ladb(x, y)
        else:
            logger.error("无可用的点击方式")
            return False

    def _tap_accessibility(self, x: int, y: int) -> bool:
        """通过无障碍服务点击"""
        try:
            response = requests.post(
                f"{self.helper_url}/tap",
                json={'x': x, 'y': y},
                timeout=5
            )

            if response.status_code == 200:
                data = response.json()
                success = data.get('success', False)
                logger.debug(f"点击 ({x}, {y}): {success}")
                return success

            return False

        except Exception as e:
            logger.error(f"点击失败 (无障碍): {e}")
            return False

    def _tap_ladb(self, x: int, y: int) -> bool:
        """通过 LADB 点击"""
        try:
            result = subprocess.run(
                ['adb', '-s', self.adb_device, 'shell', 'input', 'tap', str(x), str(y)],
                check=True,
                timeout=3
            )

            logger.debug(f"点击 ({x}, {y}): True")
            return True

        except Exception as e:
            logger.error(f"点击失败 (LADB): {e}")
            return False

    def swipe(self, x1: int, y1: int, x2: int, y2: int, duration: int = 300) -> bool:
        """
        执行滑动操作

        Args:
            x1: 起点 X 坐标
            y1: 起点 Y 坐标
            x2: 终点 X 坐标
            y2: 终点 Y 坐标
            duration: 持续时间 (毫秒)

        Returns:
            是否成功
        """
        if self.mode == self.MODE_ACCESSIBILITY:
            return self._swipe_accessibility(x1, y1, x2, y2, duration)
        elif self.mode == self.MODE_LADB:
            return self._swipe_ladb(x1, y1, x2, y2, duration)
        else:
            logger.error("无可用的滑动方式")
            return False

    def _swipe_accessibility(self, x1: int, y1: int, x2: int, y2: int, duration: int) -> bool:
        """通过无障碍服务滑动"""
        try:
            response = requests.post(
                f"{self.helper_url}/swipe",
                json={'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'duration': duration},
                timeout=10
            )

            if response.status_code == 200:
                data = response.json()
                success = data.get('success', False)
                logger.debug(f"滑动 ({x1},{y1}) -> ({x2},{y2}): {success}")
                return success

            return False

        except Exception as e:
            logger.error(f"滑动失败 (无障碍): {e}")
            return False

    def _swipe_ladb(self, x1: int, y1: int, x2: int, y2: int, duration: int) -> bool:
        """通过 LADB 滑动"""
        try:
            result = subprocess.run(
                ['adb', '-s', self.adb_device, 'shell', 'input', 'swipe',
                 str(x1), str(y1), str(x2), str(y2), str(duration)],
                check=True,
                timeout=5
            )

            logger.debug(f"滑动 ({x1},{y1}) -> ({x2},{y2}): True")
            return True

        except Exception as e:
            logger.error(f"滑动失败 (LADB): {e}")
            return False

    def input_text(self, text: str) -> bool:
        """
        输入文字

        Args:
            text: 要输入的文字

        Returns:
            是否成功
        """
        if self.mode == self.MODE_ACCESSIBILITY:
            return self._input_accessibility(text)
        elif self.mode == self.MODE_LADB:
            return self._input_ladb(text)
        else:
            logger.error("无可用的输入方式")
            return False

    def _input_accessibility(self, text: str) -> bool:
        """通过无障碍服务输入"""
        try:
            response = requests.post(
                f"{self.helper_url}/input",
                json={'text': text},
                timeout=5
            )

            if response.status_code == 200:
                data = response.json()
                success = data.get('success', False)
                logger.debug(f"输入文字: {success}")
                return success

            return False

        except Exception as e:
            logger.error(f"输入失败 (无障碍): {e}")
            return False

    def _input_ladb(self, text: str) -> bool:
        """通过 LADB 输入"""
        try:
            # ADB input text 不支持中文，需要使用其他方法
            # 这里简化处理，仅支持英文
            escaped_text = text.replace(' ', '%s')
            result = subprocess.run(
                ['adb', '-s', self.adb_device, 'shell', 'input', 'text', escaped_text],
                check=True,
                timeout=5
            )

            logger.debug(f"输入文字: True")
            return True

        except Exception as e:
            logger.error(f"输入失败 (LADB): {e}")
            return False
PYTHON_EOF
    
    print_success "混合方案脚本下载完成"
}

# 配置 GRS AI
configure_grsai() {
    print_info "配置 GRS AI..."
    
    echo ""
    echo "请输入您的 GRS AI API Key:"
    read -p "API Key: " api_key
    
    if [ -z "$api_key" ]; then
        print_warning "未输入 API Key，跳过配置"
        print_warning "您可以稍后手动配置: export PHONE_AGENT_API_KEY='your_key'"
        return
    fi
    
    # 创建配置文件
    cat > ~/.autoglm/config.sh << EOF
#!/data/data/com.termux/files/usr/bin/bash

# GRS AI 配置
export PHONE_AGENT_BASE_URL="https://api.grsai.com/v1"
export PHONE_AGENT_API_KEY="$api_key"
export PHONE_AGENT_MODEL="gpt-4-vision-preview"

# AutoGLM Helper 配置
export AUTOGLM_HELPER_URL="http://localhost:8080"
EOF
    
    # 添加到 .bashrc
    if ! grep -q "source ~/.autoglm/config.sh" ~/.bashrc; then
        echo "" >> ~/.bashrc
        echo "# AutoGLM 配置" >> ~/.bashrc
        echo "source ~/.autoglm/config.sh" >> ~/.bashrc
    fi
    
    # 立即加载配置
    source ~/.autoglm/config.sh
    
    print_success "GRS AI 配置完成"
}

# 创建启动脚本
create_launcher() {
    print_info "创建启动脚本..."

    # 创建 ~/bin 目录
    mkdir -p ~/bin

    # 创建增强版 autoglm 启动脚本
    cat > ~/bin/autoglm << 'LAUNCHER_EOF'
#!/data/data/com.termux/files/usr/bin/bash

# Open-AutoGLM 启动脚本（增强版）
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

print_info "正在启动 Open-AutoGLM..."
echo ""

# 检查1: 配置文件是否存在
if [ ! -f "$HOME/.autoglm/config.sh" ]; then
    print_error "配置文件不存在: ~/.autoglm/config.sh"
    echo ""
    echo "请运行部署脚本："
    echo "  bash deploy.sh"
    echo ""
    exit 1
fi

# 检查2: 加载配置
print_info "加载配置文件..."
source "$HOME/.autoglm/config.sh"

# 检查3: 环境变量是否配置
if [ -z "$PHONE_AGENT_API_KEY" ]; then
    print_error "环境变量 PHONE_AGENT_API_KEY 未配置"
    echo ""
    echo "请在配置文件中设置您的 GRS AI API Key:"
    echo "  编辑: nano ~/.autoglm/config.sh"
    echo "  添加: export PHONE_AGENT_API_KEY='your_api_key'"
    echo ""
    exit 1
fi

# 检查4: Open-AutoGLM 目录是否存在
if [ ! -d "$HOME/Open-AutoGLM" ]; then
    print_error "Open-AutoGLM 目录不存在: ~/Open-AutoGLM"
    echo ""
    echo "请运行部署脚本："
    echo "  bash deploy.sh"
    echo ""
    exit 1
fi

# 检查5: AutoGLM Helper 是否运行
print_info "检查 AutoGLM Helper 连接..."
if ! curl -s http://localhost:8080/status > /dev/null 2>&1; then
    print_warning "无法连接到 AutoGLM Helper (http://localhost:8080)"
    echo ""
    echo "⚠️  AutoGLM Helper 可能未启动或无障碍服务未开启"
    echo ""
    echo "请确保："
    echo "  1. AutoGLM Helper APP 已运行"
    echo "  2. 无障碍服务已开启 (设置 → 辅助功能 → AutoGLM Helper)"
    echo ""
    echo "提示: 系统也支持 LADB 备用模式，如果已配置 LADB 可继续运行"
    echo ""
    read -p "是否继续启动? (y/n): " confirm

    if [ "$confirm" != "y" ]; then
        print_info "已取消启动"
        exit 0
    fi
else
    # 检查无障碍服务状态
    status_json=$(curl -s http://localhost:8080/status)
    if echo "$status_json" | grep -q '"accessibility_enabled":true'; then
        print_success "AutoGLM Helper 已就绪（无障碍模式）"
    else
        print_warning "AutoGLM Helper 已运行，但无障碍服务未开启"
        print_info "建议开启无障碍服务以获得最佳性能"
    fi
fi

echo ""
print_success "前置检查通过，正在启动..."
echo ""

# ============================================================
# 启动 Open-AutoGLM
# ============================================================

cd "$HOME/Open-AutoGLM"

# 捕获启动错误
if ! python -m phone_agent.cli; then
    echo ""
    print_error "启动失败"
    echo ""
    echo "🔧 故障排除："
    echo "  1. 检查 API Key 是否正确"
    echo "     查看配置: cat ~/.autoglm/config.sh"
    echo ""
    echo "  2. 检查 AutoGLM Helper 状态"
    echo "     测试连接: curl http://localhost:8080/status"
    echo ""
    echo "  3. 查看详细错误信息"
    echo "     上面的错误输出包含了详细信息"
    echo ""
    echo "  4. 查看日志（如果有）"
    echo "     日志位置: ~/Open-AutoGLM/logs/"
    echo ""
    echo "  5. 重新运行部署脚本"
    echo "     命令: bash deploy.sh"
    echo ""
    exit 1
fi
LAUNCHER_EOF

    chmod +x ~/bin/autoglm

    # 确保 ~/bin 在 PATH 中
    if ! grep -q 'export PATH=$PATH:~/bin' ~/.bashrc; then
        echo 'export PATH=$PATH:~/bin' >> ~/.bashrc
    fi

    print_success "启动脚本创建完成"
    print_info "启动脚本位置: ~/bin/autoglm"
}

# 验证 AutoGLM Helper 是否就绪（带自动等待）
verify_helper_ready() {
    local max_retries=30  # 最多等待30秒
    local retry=0

    print_info "等待 AutoGLM Helper 启动..."
    echo -n "进度: "

    while [ $retry -lt $max_retries ]; do
        if curl -s http://localhost:8080/status > /dev/null 2>&1; then
            echo ""
            print_success "AutoGLM Helper 已启动！"

            # 检查无障碍服务是否开启
            local status_json=$(curl -s http://localhost:8080/status)
            if echo "$status_json" | grep -q '"accessibility_enabled":true'; then
                print_success "无障碍服务已开启"
                return 0
            else
                print_warning "AutoGLM Helper 已运行，但无障碍服务未开启"
                echo ""
                echo "请按照以下步骤开启无障碍服务:"
                echo "1. 打开 设置 → 辅助功能 → 已下载的服务"
                echo "2. 找到 AutoGLM Helper"
                echo "3. 打开开关并授予权限"
                echo ""
                read -p "开启后按回车继续..." dummy
                return 0
            fi
        fi

        retry=$((retry + 1))
        echo -n "."
        sleep 1
    done

    echo ""
    print_error "AutoGLM Helper 未响应（等待超时30秒）"
    echo ""
    echo "❌ 可能的原因："
    echo "  1. AutoGLM Helper APK 未安装"
    echo "  2. AutoGLM Helper APP 未运行"
    echo "  3. 无障碍权限未开启"
    echo "  4. Termux 无权访问本地网络"
    echo ""
    echo "🔧 解决方案："
    echo "  1. 安装 APK: 从 GitHub Releases 下载并安装"
    echo "  2. 启动 APP: 打开 AutoGLM Helper 应用"
    echo "  3. 开启权限: 设置 → 辅助功能 → AutoGLM Helper → 开启"
    echo "  4. 检查网络: 在 Termux 中运行 curl http://localhost:8080/status"
    echo ""
    echo "📝 调试信息："
    echo "  - 测试命令: curl http://localhost:8080/status"
    echo "  - 预期输出: {\"status\":\"ok\",\"accessibility_enabled\":true}"
    echo ""
    return 1
}

# 检查 AutoGLM Helper
check_helper_app() {
    print_info "检查 AutoGLM Helper APP..."

    echo ""
    echo "请确保您已经:"
    echo "1. 安装了 AutoGLM Helper APK"
    echo "2. 启动了 AutoGLM Helper APP"
    echo "3. 开启了无障碍服务权限"
    echo ""

    read -p "是否已完成以上步骤? (y/n): " confirm

    if [ "$confirm" != "y" ]; then
        print_warning "请先完成以上步骤，然后重新运行部署脚本"
        echo ""
        echo "📥 获取 APK:"
        echo "  GitHub: https://github.com/your-org/Open-AutoGLM-Hybrid/releases"
        echo "  或从项目根目录查找: AutoGLM-Helper.apk"
        echo ""
        echo "📱 安装方法:"
        echo "  方法1: 直接在手机上下载并安装"
        echo "  方法2: 使用 ADB: adb install AutoGLM-Helper.apk"
        echo ""
        exit 0
    fi

    # 验证连接（带自动等待和详细错误提示）
    if ! verify_helper_ready; then
        print_error "部署失败：无法连接到 AutoGLM Helper"
        echo ""
        echo "请解决上述问题后重新运行部署脚本："
        echo "  bash deploy.sh"
        echo ""
        exit 1
    fi
}

# 显示完成信息
show_completion() {
    print_success "部署完成！"
    
    echo ""
    echo "============================================================"
    echo "  部署成功！"
    echo "============================================================"
    echo ""
    echo "使用方法:"
    echo "  1. 确保 AutoGLM Helper 已运行并开启无障碍权限"
    echo "  2. 在 Termux 中输入: autoglm"
    echo "  3. 输入任务，如: 打开淘宝搜索蓝牙耳机"
    echo ""
    echo "配置文件:"
    echo "  ~/.autoglm/config.sh"
    echo ""
    echo "启动命令:"
    echo "  autoglm"
    echo ""
    echo "故障排除:"
    echo "  - 检查 AutoGLM Helper 是否运行"
    echo "  - 检查无障碍权限是否开启"
    echo "  - 测试连接: curl http://localhost:8080/status"
    echo ""
    echo "============================================================"
    echo ""
}

# 主函数
main() {
    print_header
    
    # 检查是否在 Termux 中运行
    if [ ! -d "/data/data/com.termux" ]; then
        print_error "此脚本必须在 Termux 中运行！"
        exit 1
    fi
    
    # 执行部署步骤
    check_network
    update_packages
    install_dependencies
    install_python_packages
    download_autoglm
    install_autoglm
    download_hybrid_scripts
    configure_grsai
    create_launcher
    check_helper_app
    show_completion
}

# 运行主函数
main
