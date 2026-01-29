"""
配置管理模块
从环境变量和配置文件读取配置
"""

import os
import secrets
from pathlib import Path

# 加载 .env 文件
try:
    from dotenv import load_dotenv
    env_file = Path(__file__).resolve().parent / '.env'
    if env_file.exists():
        load_dotenv(env_file)
except ImportError:
    # 如果没有安装 python-dotenv，尝试手动读取
    env_file = Path(__file__).resolve().parent / '.env'
    if env_file.exists():
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip()

# 项目根目录
BASE_DIR = Path(__file__).resolve().parent.parent

# Web 服务配置
WEB_HOST = os.getenv('WEB_HOST', '127.0.0.1')
WEB_PORT = int(os.getenv('WEB_PORT', '5000'))

# 认证配置
# 生成或读取 auth token（首次运行时自动生成）
AUTH_TOKEN_FILE = BASE_DIR / 'web-server' / '.auth_token'
if AUTH_TOKEN_FILE.exists():
    with open(AUTH_TOKEN_FILE, 'r') as f:
        AUTH_TOKEN = f.read().strip()
else:
    AUTH_TOKEN = secrets.token_urlsafe(32)
    AUTH_TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(AUTH_TOKEN_FILE, 'w') as f:
        f.write(AUTH_TOKEN)
    print(f"✅ 生成新的认证 Token: {AUTH_TOKEN}")
    print(f"   Token 已保存到: {AUTH_TOKEN_FILE}")

# 手机控制器配置（从 mac-server 继承）
PHONE_HELPER_URL = os.getenv('PHONE_HELPER_URL', 'http://192.168.1.100:8080')
PHONE_AGENT_API_KEY = os.getenv('PHONE_AGENT_API_KEY', '')

# 日志配置
LOG_DIR = BASE_DIR / 'logs' / 'web'
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / 'app.log'

# 任务存储配置
TASK_HISTORY_FILE = BASE_DIR / 'web-server' / 'task_history.json'

# 手机白名单配置
PHONE_WHITELIST_FILE = BASE_DIR / 'web-server' / 'phone_whitelist.json'

# 最大任务历史记录数
MAX_TASK_HISTORY = 50

# 敏感信息关键词（用于日志脱敏）
SENSITIVE_KEYWORDS = [
    'password', 'passwd', 'pwd', 'token', 'secret', 'key',
    'api_key', 'apikey', 'auth', 'credential', 'private'
]


def get_config_summary():
    """获取配置摘要（隐藏敏感信息）"""
    return {
        'web_host': WEB_HOST,
        'web_port': WEB_PORT,
        'phone_helper_url': PHONE_HELPER_URL,
        'auth_token': f"{AUTH_TOKEN[:8]}..." if AUTH_TOKEN else "未设置",
        'log_dir': str(LOG_DIR),
        'task_history_file': str(TASK_HISTORY_FILE),
    }


def validate_config():
    """验证配置完整性"""
    errors = []

    if not PHONE_AGENT_API_KEY:
        errors.append("❌ 未设置 PHONE_AGENT_API_KEY 环境变量")

    if not AUTH_TOKEN:
        errors.append("❌ 认证 Token 生成失败")

    return errors
