# frp + 腾讯云 VPS + Web 界面完整实现方案
## 深度分析报告

**版本：** 2.0.0
**日期：** 2026-01-28
**分析工具：** Sequential Thinking
**分析师：** Claude Code

---

## 目录

1. [方案概述](#方案概述)
2. [架构设计](#架构设计)
3. [技术选型深度分析](#技术选型深度分析)
4. [详细实现方案](#详细实现方案)
5. [安全性深度分析](#安全性深度分析)
6. [性能优化策略](#性能优化策略)
7. [部署流程](#部署流程)
8. [风险评估与缓解](#风险评估与缓解)
9. [与 Tailscale 方案对比](#与-tailscale-方案对比)
10. [实施时间表](#实施时间表)

---

## 方案概述

### 用户场景

**背景：**
- 用户有闲置的腾讯云服务器（VPS）
- 需要在中国大陆外网访问家里的 Mac
- Mac 运行 Open-AutoGLM 服务控制手机
- 期望通过手机浏览器发布任务

**目标：**
- 外网访问家中 Mac 服务
- Web 界面发布和监控任务
- 实时查看任务执行过程
- 简单可靠，易于部署

### 核心架构

```
┌────────────────────────────────────────────────────────────┐
│                         用户端                              │
│  ┌──────────────┐          ┌──────────────┐               │
│  │ 手机浏览器    │          │  电脑浏览器   │               │
│  │ (外网访问)   │          │  (外网访问)   │               │
│  └──────┬───────┘          └──────┬───────┘               │
│         │                          │                       │
└─────────┼──────────────────────────┼───────────────────────┘
          │ HTTPS (公网)             │
          │                          │
          ▼                          ▼
┌────────────────────────────────────────────────────────────┐
│              腾讯云 VPS (frps 服务端)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  frps        │  │  Nginx       │  │  Certbot     │     │
│  │  (7000)      │──│  (80/443)    │──│  (SSL 证书)  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                                                   │
└─────────┼───────────────────────────────────────────────────┘
          │ frp 隧道 (加密)
          │
          ▼
┌────────────────────────────────────────────────────────────┐
│                家里的 Mac (frpc 客户端)                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  frpc        │  │  Flask Web   │  │ Open-AutoGLM │     │
│  │  (客户端)     │──│  (5000)      │──│  (任务执行)   │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                  │                   │            │
└─────────┼──────────────────┼───────────────────┼────────────┘
          │                  │                   │
          │                  │                   │ HTTP
          │                  │                   ▼
          │                  │          ┌──────────────┐
          │                  │          │ Android 手机  │
          │                  │          │ AutoGLM      │
          │                  │          │ Helper       │
          │                  │          └──────────────┘
          │                  │
          └──────────────────┘
           实时日志推送 (SSE)
```

---

## 架构设计

### 1. 网络层设计

#### frp 隧道配置

**frps (腾讯云 VPS)：**
```ini
[common]
bind_port = 7000                    # frp 主端口
dashboard_port = 7500               # 控制面板端口
dashboard_user = admin
dashboard_pwd = <强密码>
token = <32位随机Token>             # 客户端认证 Token
max_pool_count = 5                  # 连接池大小
log_file = /var/log/frp/frps.log
log_level = info
authentication_timeout = 900         # 认证超时 15 分钟
```

**frpc (Mac 客户端)：**
```ini
[common]
server_addr = <腾讯云公网IP>
server_port = 7000
token = <与服务端相同的Token>
log_file = /Users/<user>/autoglm-server/logs/frpc.log
log_level = info

[web]
type = http                          # HTTP 隧道
local_ip = 127.0.0.1
local_port = 5000                    # Flask 端口
custom_domains = <您的域名或IP>
use_encryption = true                # 启用加密
use_compression = true               # 启用压缩

[web_https]
type = https                         # HTTPS 隧道（可选）
custom_domains = <您的域名>
plugin = https2http
plugin_local_addr = 127.0.0.1:5000
plugin_crt_path = /path/to/cert.crt
plugin_key_path = /path/to/cert.key
```

#### Nginx 反向代理配置

**目的：**
1. 提供 HTTPS 加密（Let's Encrypt 证书）
2. 负载均衡（未来多 Mac 支持）
3. 请求限速（防 DDoS）
4. 静态资源缓存

**配置文件（/etc/nginx/sites-available/autoglm）：**
```nginx
# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name your-domain.com;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

# HTTPS 主配置
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    # SSL 证书（Let's Encrypt）
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # SSL 优化配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # 安全头
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # 请求限速（防止滥用）
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req zone=api_limit burst=20 nodelay;

    # 反向代理到 frp
    location / {
        proxy_pass http://127.0.0.1:8080;  # frp 本地端口
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # SSE 支持
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_buffering off;
        proxy_cache off;
        chunked_transfer_encoding off;

        # 超时配置
        proxy_connect_timeout 60s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    # 静态资源缓存
    location /static/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_cache_valid 200 1d;
        expires 1d;
        add_header Cache-Control "public, immutable";
    }

    # 日志
    access_log /var/log/nginx/autoglm_access.log;
    error_log /var/log/nginx/autoglm_error.log;
}
```

### 2. 应用层设计

#### Flask Web 服务架构

```
web-server/
├── app.py                    # Flask 主应用（路由、API）
├── tasks.py                  # 任务队列管理（线程安全）
├── auth.py                   # Token 认证中间件
├── config.py                 # 配置管理（环境变量）
├── utils.py                  # 工具函数（日志脱敏、图片处理）
├── requirements.txt          # Python 依赖
├── frpc.ini                  # frp 客户端配置
├── deploy-web-frp.sh         # Mac 部署脚本
├── start-web.sh              # 启动脚本
├── templates/                # HTML 模板
│   ├── base.html             # 基础模板
│   ├── index.html            # 主页（任务提交）
│   ├── task.html             # 任务详情（实时日志）
│   └── history.html          # 历史记录
├── static/                   # 静态资源
│   ├── js/
│   │   └── app.js            # Vue.js 应用（前端逻辑）
│   ├── css/
│   │   └── style.css         # 自定义样式
│   └── images/
│       └── logo.png
└── logs/                     # 日志文件
    ├── flask.log             # Flask 日志
    ├── tasks.log             # 任务执行日志
    └── frpc.log              # frp 客户端日志
```

#### 核心模块设计

**app.py - Flask 主应用：**
```python
from flask import Flask, render_template, request, jsonify, Response
from flask_cors import CORS
import threading
import queue
import logging
from auth import require_token
from tasks import TaskManager
from config import Config

app = Flask(__name__)
CORS(app)

# 初始化配置
config = Config()
app.config.from_object(config)

# 初始化任务管理器
task_manager = TaskManager(config)

# 日志配置
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/flask.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ==================== 路由定义 ====================

@app.route('/')
def index():
    """主页：任务提交界面"""
    return render_template('index.html')

@app.route('/tasks/<task_id>')
def task_detail(task_id):
    """任务详情页：实时日志和截图"""
    return render_template('task.html', task_id=task_id)

@app.route('/history')
def history():
    """历史任务页：分页列表"""
    return render_template('history.html')

# ==================== API 接口 ====================

@app.route('/api/status')
@require_token
def api_status():
    """服务状态检查"""
    return jsonify({
        'server': 'running',
        'phone': task_manager.check_phone_connection(),
        'queue_size': task_manager.queue_size()
    })

@app.route('/api/tasks', methods=['POST'])
@require_token
def api_create_task():
    """创建新任务"""
    data = request.json
    command = data.get('command', '')

    if not command:
        return jsonify({'error': '任务命令不能为空'}), 400

    task = task_manager.create_task(command)

    return jsonify({
        'id': task.id,
        'command': task.command,
        'status': task.status,
        'created_at': task.created_at.isoformat()
    }), 201

@app.route('/api/tasks/<task_id>')
@require_token
def api_get_task(task_id):
    """获取任务详情"""
    task = task_manager.get_task(task_id)

    if not task:
        return jsonify({'error': '任务不存在'}), 404

    return jsonify(task.to_dict())

@app.route('/api/tasks/<task_id>/stream')
@require_token
def api_task_stream(task_id):
    """SSE 实时日志流"""
    task = task_manager.get_task(task_id)

    if not task:
        return jsonify({'error': '任务不存在'}), 404

    def generate():
        """SSE 生成器"""
        # 推送历史日志
        for log in task.get_logs():
            yield f"data: {json.dumps({'type': 'log', 'message': log})}\n\n"

        # 实时推送新日志
        while task.is_running():
            new_logs = task.get_new_logs()
            for log in new_logs:
                yield f"data: {json.dumps({'type': 'log', 'message': log})}\n\n"

            # 推送截图
            if task.has_new_screenshot():
                screenshot = task.get_screenshot()
                yield f"data: {json.dumps({'type': 'screenshot', 'image': screenshot})}\n\n"

            time.sleep(0.5)  # 降低 CPU 占用

        # 任务完成
        yield f"data: {json.dumps({'type': 'completed', 'result': task.result})}\n\n"

    return Response(generate(), mimetype='text/event-stream')

@app.route('/api/tasks/<task_id>/cancel', methods=['POST'])
@require_token
def api_cancel_task(task_id):
    """取消任务"""
    task = task_manager.get_task(task_id)

    if not task:
        return jsonify({'error': '任务不存在'}), 404

    success = task_manager.cancel_task(task_id)

    return jsonify({'success': success})

@app.route('/api/tasks/history')
@require_token
def api_task_history():
    """任务历史记录（分页）"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    status_filter = request.args.get('status', None)

    tasks, total = task_manager.get_history(page, per_page, status_filter)

    return jsonify({
        'tasks': [task.to_dict() for task in tasks],
        'total': total,
        'page': page,
        'per_page': per_page
    })

# ==================== 错误处理 ====================

@app.errorhandler(401)
def unauthorized(e):
    return jsonify({'error': 'Unauthorized'}), 401

@app.errorhandler(404)
def not_found(e):
    return jsonify({'error': 'Not Found'}), 404

@app.errorhandler(500)
def internal_error(e):
    logger.error(f"Internal error: {e}")
    return jsonify({'error': 'Internal Server Error'}), 500

# ==================== 启动服务 ====================

if __name__ == '__main__':
    # 启动任务执行线程
    task_manager.start()

    # 启动 Flask 服务
    app.run(
        host='127.0.0.1',  # 仅监听本地（frp 会转发）
        port=5000,
        debug=False,
        threaded=True
    )
```

**tasks.py - 任务管理器：**
```python
import queue
import threading
import uuid
import subprocess
import time
import logging
from datetime import datetime
from typing import Optional, List, Tuple
from dataclasses import dataclass, field
from enum import Enum

logger = logging.getLogger(__name__)


class TaskStatus(Enum):
    """任务状态枚举"""
    PENDING = 'pending'
    RUNNING = 'running'
    COMPLETED = 'completed'
    FAILED = 'failed'
    CANCELLED = 'cancelled'


@dataclass
class Task:
    """任务对象"""
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    command: str = ''
    status: TaskStatus = TaskStatus.PENDING
    created_at: datetime = field(default_factory=datetime.now)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    logs: List[str] = field(default_factory=list)
    screenshots: List[str] = field(default_factory=list)  # Base64 图片
    result: Optional[dict] = None
    error: Optional[str] = None
    process: Optional[subprocess.Popen] = None
    _log_position: int = 0  # 已读取的日志位置

    def to_dict(self) -> dict:
        """转换为字典"""
        return {
            'id': self.id,
            'command': self.command,
            'status': self.status.value,
            'created_at': self.created_at.isoformat(),
            'started_at': self.started_at.isoformat() if self.started_at else None,
            'completed_at': self.completed_at.isoformat() if self.completed_at else None,
            'duration': self.get_duration(),
            'logs': self.logs,
            'screenshots': self.screenshots,
            'result': self.result,
            'error': self.error
        }

    def get_duration(self) -> Optional[float]:
        """获取任务执行时长（秒）"""
        if not self.started_at:
            return None

        end_time = self.completed_at or datetime.now()
        return (end_time - self.started_at).total_seconds()

    def is_running(self) -> bool:
        """是否正在运行"""
        return self.status == TaskStatus.RUNNING

    def add_log(self, message: str):
        """添加日志"""
        timestamp = datetime.now().strftime('%H:%M:%S')
        self.logs.append(f"[{timestamp}] {message}")

    def get_logs(self) -> List[str]:
        """获取所有日志"""
        return self.logs

    def get_new_logs(self) -> List[str]:
        """获取新增日志（自上次读取后）"""
        new_logs = self.logs[self._log_position:]
        self._log_position = len(self.logs)
        return new_logs

    def add_screenshot(self, image_base64: str):
        """添加截图"""
        self.screenshots.append(image_base64)

    def has_new_screenshot(self) -> bool:
        """是否有新截图"""
        return len(self.screenshots) > 0

    def get_screenshot(self) -> Optional[str]:
        """获取最新截图"""
        return self.screenshots[-1] if self.screenshots else None


class TaskManager:
    """任务管理器（线程安全）"""

    def __init__(self, config):
        self.config = config
        self.tasks = {}  # {task_id: Task}
        self.task_queue = queue.Queue()
        self.worker_thread = None
        self.running = False
        self.lock = threading.Lock()

    def start(self):
        """启动任务执行线程"""
        if self.running:
            return

        self.running = True
        self.worker_thread = threading.Thread(target=self._worker, daemon=True)
        self.worker_thread.start()
        logger.info("任务管理器已启动")

    def stop(self):
        """停止任务管理器"""
        self.running = False
        if self.worker_thread:
            self.worker_thread.join(timeout=5)
        logger.info("任务管理器已停止")

    def create_task(self, command: str) -> Task:
        """创建新任务"""
        task = Task(command=command)

        with self.lock:
            self.tasks[task.id] = task
            self.task_queue.put(task.id)

        logger.info(f"任务已创建: {task.id} - {command}")
        return task

    def get_task(self, task_id: str) -> Optional[Task]:
        """获取任务对象"""
        with self.lock:
            return self.tasks.get(task_id)

    def cancel_task(self, task_id: str) -> bool:
        """取消任务"""
        task = self.get_task(task_id)

        if not task:
            return False

        if task.status == TaskStatus.RUNNING:
            # 终止进程
            if task.process:
                task.process.terminate()
                try:
                    task.process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    task.process.kill()

            task.status = TaskStatus.CANCELLED
            task.completed_at = datetime.now()
            task.add_log("任务已取消")
            logger.info(f"任务已取消: {task_id}")
            return True

        elif task.status == TaskStatus.PENDING:
            task.status = TaskStatus.CANCELLED
            task.add_log("任务已取消（未开始）")
            logger.info(f"任务已取消: {task_id}")
            return True

        return False

    def queue_size(self) -> int:
        """获取队列大小"""
        return self.task_queue.qsize()

    def check_phone_connection(self) -> bool:
        """检查手机连接状态"""
        try:
            import requests
            response = requests.get(
                f"{self.config.PHONE_HELPER_URL}/status",
                timeout=3
            )
            return response.status_code == 200
        except:
            return False

    def get_history(self, page: int, per_page: int, status_filter: Optional[str] = None) -> Tuple[List[Task], int]:
        """获取历史任务（分页）"""
        with self.lock:
            # 筛选任务
            tasks = list(self.tasks.values())

            if status_filter:
                try:
                    status = TaskStatus(status_filter)
                    tasks = [t for t in tasks if t.status == status]
                except ValueError:
                    pass

            # 按创建时间倒序排序
            tasks.sort(key=lambda t: t.created_at, reverse=True)

            # 分页
            total = len(tasks)
            start = (page - 1) * per_page
            end = start + per_page

            return tasks[start:end], total

    def _worker(self):
        """任务执行线程（串行）"""
        logger.info("任务执行线程已启动")

        while self.running:
            try:
                # 从队列获取任务（阻塞，超时 1 秒）
                task_id = self.task_queue.get(timeout=1)
                task = self.get_task(task_id)

                if not task:
                    continue

                # 执行任务
                self._execute_task(task)

            except queue.Empty:
                continue
            except Exception as e:
                logger.error(f"任务执行线程错误: {e}", exc_info=True)

    def _execute_task(self, task: Task):
        """执行单个任务"""
        logger.info(f"开始执行任务: {task.id} - {task.command}")

        task.status = TaskStatus.RUNNING
        task.started_at = datetime.now()
        task.add_log(f"任务开始: {task.command}")

        try:
            # 构建命令
            cmd = [
                'python3',
                'Open-AutoGLM/main.py',
                '--task', task.command
            ]

            # 启动进程
            task.process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,  # 行缓冲
                cwd=self.config.WORK_DIR
            )

            # 实时读取输出
            for line in task.process.stdout:
                line = line.strip()
                if line:
                    task.add_log(line)

            # 等待进程结束
            return_code = task.process.wait(timeout=300)  # 5 分钟超时

            # 更新任务状态
            if return_code == 0:
                task.status = TaskStatus.COMPLETED
                task.result = {'success': True}
                task.add_log("任务完成")
                logger.info(f"任务完成: {task.id}")
            else:
                task.status = TaskStatus.FAILED
                task.error = f"进程退出码: {return_code}"
                task.add_log(f"任务失败: {task.error}")
                logger.error(f"任务失败: {task.id} - {task.error}")

        except subprocess.TimeoutExpired:
            task.process.kill()
            task.status = TaskStatus.FAILED
            task.error = "任务超时（5 分钟）"
            task.add_log(task.error)
            logger.error(f"任务超时: {task.id}")

        except Exception as e:
            task.status = TaskStatus.FAILED
            task.error = str(e)
            task.add_log(f"任务错误: {task.error}")
            logger.error(f"任务错误: {task.id} - {e}", exc_info=True)

        finally:
            task.completed_at = datetime.now()
            task.process = None
```

**auth.py - Token 认证：**
```python
from functools import wraps
from flask import request, jsonify
import os
import secrets

# 从环境变量读取 Token
AUTH_TOKEN = os.getenv('WEB_AUTH_TOKEN')

if not AUTH_TOKEN:
    # 自动生成（仅用于开发）
    AUTH_TOKEN = secrets.token_urlsafe(32)
    print(f"警告: WEB_AUTH_TOKEN 未设置，使用临时 Token: {AUTH_TOKEN}")


def require_token(f):
    """Token 认证装饰器"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # 从请求头获取 Token
        auth_header = request.headers.get('Authorization', '')
        token = auth_header.replace('Bearer ', '').strip()

        # 验证 Token
        if token != AUTH_TOKEN:
            return jsonify({'error': 'Unauthorized'}), 401

        return f(*args, **kwargs)

    return decorated_function
```

**config.py - 配置管理：**
```python
import os
from dotenv import load_dotenv

# 加载 .env 文件
load_dotenv('config.env')


class Config:
    """配置类"""

    # GRS AI API Key
    PHONE_AGENT_API_KEY = os.getenv('PHONE_AGENT_API_KEY')

    # 手机地址
    PHONE_HELPER_URL = os.getenv('PHONE_HELPER_URL', 'http://localhost:8080')

    # Web Token
    WEB_AUTH_TOKEN = os.getenv('WEB_AUTH_TOKEN')

    # Flask 配置
    SECRET_KEY = os.getenv('SECRET_KEY', os.urandom(24).hex())
    DEBUG = os.getenv('FLASK_DEBUG', 'False') == 'True'

    # 工作目录
    WORK_DIR = os.path.expanduser('~/autoglm-server')

    # 日志配置
    LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
    LOG_FILE = os.path.join(WORK_DIR, 'logs/flask.log')

    # 任务配置
    MAX_TASK_TIMEOUT = 300  # 5 分钟
    MAX_TASK_HISTORY = 100  # 保留最近 100 条任务
```

---

## 技术选型深度分析

### 1. frp vs Tailscale vs ngrok

| 特性 | frp | Tailscale | ngrok |
|------|-----|-----------|-------|
| **部署复杂度** | 中（需配置 VPS） | 低（零配置） | 低（SaaS） |
| **成本** | 低（VPS 复用） | 免费（个人） | 免费有限 |
| **性能** | 高（直连 VPS） | 高（P2P） | 中（中继） |
| **稳定性** | 高（自建） | 高（商业） | 中（免费版） |
| **安全性** | 高（完全可控） | 高（加密） | 中（共享域名） |
| **自定义域名** | 是 | 否 | 付费 |
| **中国大陆访问** | 好（VPS 在国内） | 一般（墙） | 差（墙） |
| **适合场景** | 有 VPS，需自定义 | 个人快速部署 | 临时测试 |

**选择 frp 的理由：**
1. ✅ 用户已有腾讯云 VPS，成本为零
2. ✅ 完全可控，无第三方依赖
3. ✅ 支持自定义域名和 HTTPS
4. ✅ 中国大陆访问速度快
5. ✅ 学习价值高，可扩展性强

**Tailscale 的优势：**
- 零配置，适合快速部署
- P2P 连接，延迟低
- 但是：不支持公网访问（需手机安装 Tailscale）

**推荐方案：**
- 主要方案：frp（公网访问）
- 备用方案：Tailscale（快速部署）

### 2. Flask vs FastAPI vs Django

| 特性 | Flask | FastAPI | Django |
|------|-------|---------|--------|
| **学习曲线** | 平缓 | 陡峭 | 陡峭 |
| **轻量级** | 是 | 是 | 否 |
| **SSE 支持** | 原生 | 需插件 | 需插件 |
| **异步** | 否 | 是 | 部分 |
| **ORM** | 可选 | 可选 | 内置 |
| **API 文档** | 手动 | 自动 | 手动 |
| **生态** | 成熟 | 新兴 | 成熟 |
| **适合场景** | 小型项目 | API 服务 | 大型项目 |

**选择 Flask 的理由：**
1. ✅ 轻量级，易于集成
2. ✅ 原生支持 SSE（日志推送）
3. ✅ 学习曲线平缓
4. ✅ 与现有 Python 代码无缝集成
5. ✅ 不需要 ORM（任务数据存内存）

### 3. SSE vs WebSocket vs 轮询

| 特性 | SSE | WebSocket | 轮询 |
|------|-----|-----------|------|
| **通信方向** | 单向（服务器→客户端） | 双向 | 单向 |
| **实现复杂度** | 简单 | 复杂 | 简单 |
| **浏览器支持** | 原生 EventSource | 原生 WebSocket | 原生 fetch |
| **自动重连** | 是 | 否（需手动） | 否 |
| **资源占用** | 低 | 中 | 高 |
| **适合场景** | 日志推送、状态更新 | 聊天、游戏 | 低频更新 |

**选择 SSE 的理由：**
1. ✅ 日志输出是单向流，SSE 最适合
2. ✅ 原生浏览器支持，无需额外库
3. ✅ 自动重连机制
4. ✅ Flask 直接支持（yield 即可）
5. ✅ 资源占用低

---

## 详细实现方案

### 1. VPS 端部署脚本

**文件：vps-setup/install-frps.sh**

```bash
#!/bin/bash

# frps 服务端一键部署脚本（腾讯云 VPS）
# 版本: 1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo ""
    echo "========================================="
    echo "  frp 服务端部署脚本"
    echo "  版本: 1.0.0"
    echo "========================================="
    echo ""
}

# 检查 root 权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 root 用户运行此脚本"
        echo "使用: sudo bash install-frps.sh"
        exit 1
    fi
}

# 检测系统版本
check_system() {
    print_info "检测系统版本..."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_error "无法检测系统版本"
        exit 1
    fi

    print_success "系统: $OS $VER"
}

# 安装依赖
install_dependencies() {
    print_info "安装依赖..."

    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y wget curl tar
    elif command -v yum &> /dev/null; then
        yum install -y wget curl tar
    else
        print_error "不支持的包管理器"
        exit 1
    fi

    print_success "依赖安装完成"
}

# 下载 frp
download_frp() {
    print_info "下载 frp..."

    # 获取最新版本
    FRP_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')

    if [ -z "$FRP_VERSION" ]; then
        FRP_VERSION="v0.53.2"  # 备用版本
        print_warning "无法获取最新版本，使用备用版本: $FRP_VERSION"
    else
        print_success "最新版本: $FRP_VERSION"
    fi

    # 下载地址
    ARCH=$(uname -m)
    if [ "$ARCH" == "x86_64" ]; then
        DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${FRP_VERSION}/frp_${FRP_VERSION#v}_linux_amd64.tar.gz"
    elif [ "$ARCH" == "aarch64" ]; then
        DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${FRP_VERSION}/frp_${FRP_VERSION#v}_linux_arm64.tar.gz"
    else
        print_error "不支持的架构: $ARCH"
        exit 1
    fi

    print_info "下载地址: $DOWNLOAD_URL"

    # 下载
    cd /tmp
    wget -O frp.tar.gz "$DOWNLOAD_URL"

    # 解压
    tar -xzf frp.tar.gz
    rm frp.tar.gz

    # 安装
    FRP_DIR=$(ls -d frp_*)
    cd $FRP_DIR

    cp frps /usr/local/bin/
    chmod +x /usr/local/bin/frps

    mkdir -p /etc/frp
    mkdir -p /var/log/frp

    print_success "frp 下载完成"
}

# 生成 Token
generate_token() {
    TOKEN=$(openssl rand -hex 16)
    echo "$TOKEN"
}

# 配置 frp
configure_frp() {
    print_info "配置 frp..."

    # 生成 Token
    TOKEN=$(generate_token)
    DASHBOARD_PWD=$(generate_token)

    # 创建配置文件
    cat > /etc/frp/frps.ini << EOF
[common]
bind_port = 7000
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = $DASHBOARD_PWD
token = $TOKEN
max_pool_count = 5
log_file = /var/log/frp/frps.log
log_level = info
authentication_timeout = 900
EOF

    # 保存 Token
    echo "FRP_TOKEN=$TOKEN" > /etc/frp/token.env
    chmod 600 /etc/frp/token.env

    print_success "配置文件已创建: /etc/frp/frps.ini"
    print_success "Token 已保存: /etc/frp/token.env"
    print_warning "请妥善保管 Token: $TOKEN"
}

# 创建 systemd 服务
create_systemd_service() {
    print_info "创建 systemd 服务..."

    cat > /etc/systemd/system/frps.service << EOF
[Unit]
Description=frp server
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.ini
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable frps

    print_success "systemd 服务已创建"
}

# 配置防火墙
configure_firewall() {
    print_info "配置防火墙..."

    # ufw（Ubuntu/Debian）
    if command -v ufw &> /dev/null; then
        ufw allow 7000/tcp
        ufw allow 7500/tcp
        ufw allow 80/tcp
        ufw allow 443/tcp
        print_success "ufw 防火墙已配置"

    # firewalld（CentOS/RedHat）
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=7000/tcp
        firewall-cmd --permanent --add-port=7500/tcp
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --reload
        print_success "firewalld 防火墙已配置"

    else
        print_warning "未检测到防火墙，请手动开放端口: 7000, 7500, 80, 443"
    fi
}

# 安装 Nginx
install_nginx() {
    print_info "安装 Nginx..."

    if command -v nginx &> /dev/null; then
        print_warning "Nginx 已安装，跳过"
        return
    fi

    if command -v apt-get &> /dev/null; then
        apt-get install -y nginx
    elif command -v yum &> /dev/null; then
        yum install -y nginx
    fi

    systemctl enable nginx

    print_success "Nginx 安装完成"
}

# 安装 Certbot
install_certbot() {
    print_info "安装 Certbot（SSL 证书）..."

    if command -v certbot &> /dev/null; then
        print_warning "Certbot 已安装，跳过"
        return
    fi

    if command -v apt-get &> /dev/null; then
        apt-get install -y certbot python3-certbot-nginx
    elif command -v yum &> /dev/null; then
        yum install -y certbot python3-certbot-nginx
    fi

    print_success "Certbot 安装完成"
}

# 配置 Nginx 反向代理
configure_nginx() {
    print_info "配置 Nginx 反向代理..."

    # 询问域名
    read -p "请输入您的域名（例如: autoglm.example.com）: " DOMAIN

    if [ -z "$DOMAIN" ]; then
        print_warning "未输入域名，跳过 Nginx 配置"
        return
    fi

    # 创建配置文件
    cat > /etc/nginx/sites-available/autoglm << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # SSE 支持
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_buffering off;
        proxy_cache off;
        chunked_transfer_encoding off;

        # 超时
        proxy_connect_timeout 60s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF

    # 启用站点
    if [ -d /etc/nginx/sites-enabled ]; then
        ln -sf /etc/nginx/sites-available/autoglm /etc/nginx/sites-enabled/
    fi

    # 测试配置
    nginx -t

    # 重载 Nginx
    systemctl reload nginx

    print_success "Nginx 配置完成"

    # 申请 SSL 证书
    read -p "是否申请 SSL 证书？(y/n): " APPLY_SSL

    if [ "$APPLY_SSL" == "y" ]; then
        print_info "申请 SSL 证书..."
        certbot --nginx -d $DOMAIN
        print_success "SSL 证书申请完成"
    fi
}

# 启动 frp 服务
start_frp() {
    print_info "启动 frp 服务..."

    systemctl start frps

    if systemctl is-active --quiet frps; then
        print_success "frp 服务已启动"
    else
        print_error "frp 服务启动失败"
        journalctl -u frps -n 20
        exit 1
    fi
}

# 显示完成信息
show_completion() {
    echo ""
    echo "========================================="
    print_success "部署完成！"
    echo "========================================="
    echo ""
    echo "frp 服务器配置:"
    echo "  - 主端口: 7000"
    echo "  - 控制面板: http://$(curl -s ip.sb):7500"
    echo "  - 用户名: admin"
    echo "  - 密码: $(grep dashboard_pwd /etc/frp/frps.ini | cut -d'=' -f2 | xargs)"
    echo ""
    echo "认证 Token:"
    echo "  - $(grep token /etc/frp/frps.ini | cut -d'=' -f2 | xargs)"
    echo "  - 已保存到: /etc/frp/token.env"
    echo ""
    echo "下一步："
    echo "1. 在 Mac 上运行 deploy-web-frp.sh"
    echo "2. 配置 frpc.ini 使用上述 Token"
    echo "3. 启动 Mac 客户端"
    echo ""
}

# 主函数
main() {
    print_header
    check_root
    check_system
    install_dependencies
    download_frp
    configure_frp
    create_systemd_service
    configure_firewall
    install_nginx
    install_certbot
    configure_nginx
    start_frp
    show_completion
}

main
```

### 2. Mac 端部署脚本

**文件：web-server/deploy-web-frp.sh**

```bash
#!/bin/bash

# Open-AutoGLM Web 服务器 + frp 客户端部署脚本
# 版本: 2.0.0 (frp 版本)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo ""
    echo "============================================================"
    echo "  Open-AutoGLM Web 服务器 + frp 部署"
    echo "  版本: 2.0.0 (frp 版本)"
    echo "============================================================"
    echo ""
}

# 检查 macOS
check_macos() {
    print_info "检查 macOS 版本..."
    os_version=$(sw_vers -productVersion)
    print_success "macOS 版本: $os_version"
}

# 检查 Homebrew
check_homebrew() {
    print_info "检查 Homebrew..."
    if ! command -v brew &> /dev/null; then
        print_warning "Homebrew 未安装，正在安装..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    print_success "Homebrew: $(brew --version | head -n1)"
}

# 检查 Python
check_python() {
    print_info "检查 Python..."
    if ! command -v python3 &> /dev/null; then
        print_warning "Python 3 未安装，正在安装..."
        brew install python@3.11
    fi
    print_success "Python: $(python3 --version)"
}

# 下载 frpc
download_frpc() {
    print_info "下载 frp 客户端..."

    # 获取最新版本
    FRP_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' || echo "v0.53.2")

    print_info "版本: $FRP_VERSION"

    # 检测架构
    ARCH=$(uname -m)
    if [ "$ARCH" == "x86_64" ]; then
        DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${FRP_VERSION}/frp_${FRP_VERSION#v}_darwin_amd64.tar.gz"
    elif [ "$ARCH" == "arm64" ]; then
        DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${FRP_VERSION}/frp_${FRP_VERSION#v}_darwin_arm64.tar.gz"
    else
        print_error "不支持的架构: $ARCH"
        exit 1
    fi

    # 下载
    cd /tmp
    curl -L -o frp.tar.gz "$DOWNLOAD_URL"

    # 解压
    tar -xzf frp.tar.gz
    rm frp.tar.gz

    # 安装
    FRP_DIR=$(ls -d frp_*)
    cd $FRP_DIR

    mkdir -p ~/autoglm-server/frp
    cp frpc ~/autoglm-server/frp/
    chmod +x ~/autoglm-server/frp/frpc

    print_success "frp 客户端安装完成"
}

# 创建虚拟环境
create_venv() {
    print_info "创建 Python 虚拟环境..."

    cd ~/autoglm-server

    if [ -d "venv" ]; then
        print_warning "虚拟环境已存在"
    else
        python3 -m venv venv
        print_success "虚拟环境创建完成"
    fi

    source venv/bin/activate
}

# 安装 Python 依赖
install_python_packages() {
    print_info "安装 Python 依赖..."

    source ~/autoglm-server/venv/bin/activate

    pip install --upgrade pip
    pip install -r requirements.txt

    print_success "依赖安装完成"
}

# 克隆 Open-AutoGLM
clone_autoglm() {
    print_info "下载 Open-AutoGLM..."

    cd ~/autoglm-server

    if [ -d "Open-AutoGLM" ]; then
        print_warning "Open-AutoGLM 已存在"
        cd Open-AutoGLM
        git pull origin main || print_warning "更新失败"
        cd ..
    else
        git clone https://github.com/zai-org/Open-AutoGLM.git
        print_success "下载完成"
    fi
}

# 配置 frpc
configure_frpc() {
    print_info "配置 frp 客户端..."

    # 询问服务器信息
    read -p "请输入 frp 服务器 IP 地址: " FRP_SERVER
    read -p "请输入 frp Token: " FRP_TOKEN
    read -p "请输入您的域名（或直接回车使用 IP）: " FRP_DOMAIN

    if [ -z "$FRP_DOMAIN" ]; then
        FRP_DOMAIN="$FRP_SERVER"
    fi

    # 创建配置文件
    cat > ~/autoglm-server/frp/frpc.ini << EOF
[common]
server_addr = $FRP_SERVER
server_port = 7000
token = $FRP_TOKEN
log_file = /Users/$(whoami)/autoglm-server/logs/frpc.log
log_level = info

[web]
type = http
local_ip = 127.0.0.1
local_port = 5000
custom_domains = $FRP_DOMAIN
use_encryption = true
use_compression = true
EOF

    print_success "frpc 配置完成"
    print_info "配置文件: ~/autoglm-server/frp/frpc.ini"
}

# 创建配置文件
create_config() {
    print_info "创建配置文件..."

    # 生成 Token
    WEB_TOKEN=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")

    cat > ~/autoglm-server/config.env << EOF
# GRS AI API Key（必填）
export PHONE_AGENT_API_KEY="your_api_key_here"

# 手机 AutoGLM Helper 地址
export PHONE_HELPER_URL="http://localhost:8080"

# Web Token（自动生成）
export WEB_AUTH_TOKEN="$WEB_TOKEN"

# Flask 配置
export FLASK_DEBUG="False"
export FLASK_PORT="5000"
export LOG_LEVEL="INFO"
EOF

    print_success "配置文件已创建"
    print_warning "请编辑 config.env 填入 API Key 和手机 IP"
    print_info "Web Token: $WEB_TOKEN"
}

# 创建启动脚本
create_start_script() {
    print_info "创建启动脚本..."

    cat > ~/autoglm-server/start-web-frp.sh << 'EOF'
#!/bin/bash

cd ~/autoglm-server

# 加载配置
source config.env

# 检查配置
if [ "$PHONE_AGENT_API_KEY" = "your_api_key_here" ]; then
    echo "错误: 请先在 config.env 中配置 API Key"
    exit 1
fi

# 激活虚拟环境
source venv/bin/activate

echo "=========================================="
echo "  Open-AutoGLM Web 服务器"
echo "=========================================="
echo ""
echo "服务器地址: http://127.0.0.1:5000"
echo "Web Token: $WEB_AUTH_TOKEN"
echo "手机地址: $PHONE_HELPER_URL"
echo ""

# 创建日志目录
mkdir -p logs

# 启动 frp 客户端（后台）
echo "启动 frp 客户端..."
./frp/frpc -c frp/frpc.ini &
FRP_PID=$!
echo "frp 客户端 PID: $FRP_PID"

# 等待 frp 启动
sleep 2

# 启动 Flask
echo ""
echo "启动 Web 服务器..."
python app.py

# 清理
kill $FRP_PID 2>/dev/null
EOF

    chmod +x ~/autoglm-server/start-web-frp.sh
    print_success "启动脚本已创建"
}

# 创建 requirements.txt
create_requirements() {
    print_info "创建 requirements.txt..."

    cat > ~/autoglm-server/requirements.txt << EOF
Flask==3.0.0
Flask-CORS==4.0.0
requests==2.31.0
Pillow==10.1.0
python-dotenv==1.0.0
EOF

    print_success "requirements.txt 已创建"
}

# 主函数
main() {
    print_header
    check_macos
    check_homebrew
    check_python

    # 创建工作目录
    mkdir -p ~/autoglm-server
    mkdir -p ~/autoglm-server/logs

    download_frpc
    create_requirements
    create_venv
    install_python_packages
    clone_autoglm
    configure_frpc
    create_config
    create_start_script

    echo ""
    echo "=========================================="
    print_success "部署完成！"
    echo "=========================================="
    echo ""
    echo "下一步："
    echo "1. 编辑配置: nano ~/autoglm-server/config.env"
    echo "2. 填入 API Key 和手机 IP"
    echo "3. 启动服务: cd ~/autoglm-server && ./start-web-frp.sh"
    echo ""
    echo "访问地址: http://$(grep custom_domains ~/autoglm-server/frp/frpc.ini | cut -d'=' -f2 | xargs)"
    echo "Web Token: $(grep WEB_AUTH_TOKEN ~/autoglm-server/config.env | cut -d'=' -f2 | xargs | tr -d '\"')"
    echo ""
}

main
```

---

## 安全性深度分析

### 1. 威胁模型

**潜在威胁：**
1. 未授权访问 Web 界面
2. Token 泄露
3. 中间人攻击（MITM）
4. DDoS 攻击
5. 日志泄露敏感信息
6. frp 隧道劫持

### 2. 安全措施

#### 2.1 frp 隧道加密

```ini
# frpc.ini
[web]
use_encryption = true        # 启用 AES-128 加密
use_compression = true       # 启用 snappy 压缩
```

**原理：**
- frp 使用 Token 认证客户端
- 数据传输使用 AES-128-CFB 加密
- 防止中间人窃听

#### 2.2 Token 认证

**Token 生成：**
```python
import secrets
token = secrets.token_urlsafe(32)  # 256 位随机
```

**存储方式：**
- 环境变量（不提交到 Git）
- 文件权限 600（仅所有者可读）

**传输方式：**
- HTTP Authorization Header
- 不在 URL 中传递（防日志泄露）

#### 2.3 HTTPS 加密

**Let's Encrypt 证书：**
```bash
certbot --nginx -d your-domain.com
```

**强制 HTTPS：**
```nginx
# Nginx 配置
server {
    listen 80;
    return 301 https://$host$request_uri;
}
```

#### 2.4 请求限速

**Nginx 限速：**
```nginx
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req zone=api_limit burst=20 nodelay;
```

**作用：**
- 防止暴力破解 Token
- 防止 DDoS 攻击
- 限制单 IP 请求频率

#### 2.5 IP 白名单（可选）

**Flask 中间件：**
```python
ALLOWED_IPS = ['1.2.3.4', '5.6.7.8']

@app.before_request
def check_ip():
    if request.remote_addr not in ALLOWED_IPS:
        abort(403)
```

**适用场景：**
- 固定 IP 访问（办公室、家庭）
- 更高安全要求

#### 2.6 日志脱敏

**正则替换：**
```python
SENSITIVE_PATTERNS = [
    (r'password["\']?\s*[:=]\s*["\']?(\S+)', 'password: ***'),
    (r'token["\']?\s*[:=]\s*["\']?(\S+)', 'token: ***'),
    (r'\d{15,19}', '****'),  # 银行卡号
    (r'[a-zA-Z0-9]{32,}', '***TOKEN***'),  # 长字符串
]

def sanitize_log(log: str) -> str:
    for pattern, replacement in SENSITIVE_PATTERNS:
        log = re.sub(pattern, replacement, log, flags=re.IGNORECASE)
    return log
```

---

## 性能优化策略

### 1. frp 性能优化

```ini
[common]
max_pool_count = 5           # 连接池大小
tcp_mux = true              # TCP 多路复用
pool_count = 1              # 预创建连接数
```

**效果：**
- 减少连接建立时间
- 提高并发能力

### 2. Nginx 优化

```nginx
# 工作进程数
worker_processes auto;

# 连接数
events {
    worker_connections 1024;
}

# Gzip 压缩
gzip on;
gzip_types text/plain text/css application/json application/javascript;

# 静态资源缓存
location /static/ {
    expires 1d;
    add_header Cache-Control "public, immutable";
}
```

### 3. Flask 优化

```python
# 使用 gunicorn 代替 Flask 内置服务器
gunicorn -w 4 -b 127.0.0.1:5000 app:app

# -w 4: 4 个工作进程
# 适合 CPU 密集型任务
```

### 4. SSE 优化

```python
def generate():
    """优化的 SSE 生成器"""
    while task.is_running():
        # 批量推送（减少网络开销）
        logs = task.get_new_logs()
        if logs:
            yield f"data: {json.dumps({'type': 'logs', 'messages': logs})}\n\n"

        time.sleep(0.5)  # 降低 CPU 占用
```

### 5. 数据库优化（未来）

**当前：内存存储**
- 优点：快速
- 缺点：重启丢失

**未来：SQLite**
```python
import sqlite3

# 持久化任务
def save_task(task):
    conn = sqlite3.connect('tasks.db')
    c = conn.cursor()
    c.execute('INSERT INTO tasks VALUES (?, ?, ?)', (task.id, task.command, task.status))
    conn.commit()
    conn.close()
```

---

## 部署流程

### 阶段 1：VPS 端部署（10 分钟）

**步骤：**
```bash
# 1. SSH 登录 VPS
ssh root@your-vps-ip

# 2. 下载部署脚本
wget https://raw.githubusercontent.com/your-repo/vps-setup/install-frps.sh

# 3. 运行部署脚本
bash install-frps.sh

# 4. 记录 Token
cat /etc/frp/token.env

# 5. 配置域名（可选）
# 输入域名后自动申请 SSL 证书

# 6. 检查服务状态
systemctl status frps
curl http://localhost:7500  # 控制面板
```

**验收标准：**
- ✅ frps 服务运行中
- ✅ 端口 7000, 7500, 80, 443 已开放
- ✅ Token 已生成并保存
- ✅ Nginx 已配置（如有域名）

### 阶段 2：Mac 端部署（10 分钟）

**步骤：**
```bash
# 1. 下载部署脚本
cd ~/Downloads
curl -O https://raw.githubusercontent.com/your-repo/web-server/deploy-web-frp.sh

# 2. 运行部署脚本
bash deploy-web-frp.sh

# 3. 输入 VPS 信息
# - VPS IP
# - frp Token
# - 域名（或留空）

# 4. 编辑配置文件
nano ~/autoglm-server/config.env

# 填入:
# - GRS AI API Key
# - 手机 IP 地址

# 5. 启动服务
cd ~/autoglm-server
./start-web-frp.sh

# 6. 检查日志
tail -f logs/frpc.log
tail -f logs/flask.log
```

**验收标准：**
- ✅ frpc 连接成功（日志显示 "connected"）
- ✅ Flask 服务运行在 5000 端口
- ✅ 可以访问 http://localhost:5000

### 阶段 3：测试（5 分钟）

**步骤：**
```bash
# 1. 测试本地访问
curl http://localhost:5000/api/status \
  -H "Authorization: Bearer YOUR_TOKEN"

# 2. 测试外网访问（手机）
# 打开浏览器访问: http://your-domain.com
# 或: http://your-vps-ip

# 3. 提交测试任务
# 在 Web 界面输入: "打开淘宝"
# 观察实时日志

# 4. 检查手机执行
# 查看手机是否打开淘宝
```

**验收标准：**
- ✅ 外网可访问 Web 界面
- ✅ Token 认证生效
- ✅ 任务提交成功
- ✅ 实时日志推送正常
- ✅ 手机执行任务成功

---

## 风险评估与缓解

### 风险矩阵

| 风险 | 概率 | 影响 | 等级 | 缓解措施 |
|------|------|------|------|----------|
| Token 泄露 | 中 | 高 | 🔴 高 | Token 轮换、IP 白名单 |
| frp 隧道中断 | 中 | 中 | 🟡 中 | 自动重连、监控告警 |
| VPS 被攻击 | 低 | 高 | 🟡 中 | 防火墙、限速、日志审计 |
| 手机离线 | 高 | 低 | 🟢 低 | 连接检测、友好提示 |
| 任务超时 | 中 | 低 | 🟢 低 | 超时控制、任务取消 |
| 日志泄露 | 中 | 中 | 🟡 中 | 日志脱敏、访问控制 |

### 具体缓解措施

#### 1. Token 泄露

**问题：** Token 被第三方获取，可控制手机

**缓解：**
```bash
# 定期轮换 Token（每月）
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# 更新 config.env
export WEB_AUTH_TOKEN="new_token"

# 重启服务
./start-web-frp.sh
```

**监控：**
```python
# 记录所有 API 访问
@app.before_request
def log_request():
    logger.info(f"{request.remote_addr} {request.method} {request.path}")
```

#### 2. frp 隧道中断

**问题：** 网络波动导致隧道断开

**缓解：**
```ini
# frpc.ini 自动重连
[common]
heartbeat_interval = 30      # 心跳间隔 30 秒
heartbeat_timeout = 90       # 心跳超时 90 秒
```

**监控脚本：**
```bash
#!/bin/bash
# check-frpc.sh

while true; do
    if ! pgrep -f "frpc" > /dev/null; then
        echo "frpc 已停止，正在重启..."
        cd ~/autoglm-server
        ./frp/frpc -c frp/frpc.ini &
    fi
    sleep 60
done
```

#### 3. VPS 被攻击

**缓解：**
```bash
# 安装 fail2ban
apt-get install fail2ban

# 配置规则
cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = 22
maxretry = 3
bantime = 3600
EOF

systemctl restart fail2ban
```

---

## 与 Tailscale 方案对比

### 对比表

| 特性 | frp 方案 | Tailscale 方案 |
|------|----------|----------------|
| **部署复杂度** | 中（需配置 VPS） | 低（零配置） |
| **访问方式** | 任何浏览器 | 需安装 Tailscale |
| **成本** | VPS 成本 | 免费（个人） |
| **性能** | 中（中继） | 高（P2P） |
| **公网访问** | 是 | 否（需手机安装） |
| **自定义域名** | 是 | 否 |
| **中国大陆访问** | 好 | 一般 |
| **适合场景** | 公网分享、多人访问 | 个人快速部署 |

### 推荐策略

**主方案：frp**
- 适合：有 VPS、需公网访问、多人使用
- 优点：任何设备可访问、支持自定义域名

**备用方案：Tailscale**
- 适合：快速部署、个人使用、无 VPS
- 优点：零配置、P2P 快速、安全性高

**混合方案：**
```bash
# 同时部署两种方案
# 1. 主要通过 frp 公网访问
# 2. frp 故障时使用 Tailscale 备用
# 3. 对性能要求高的任务使用 Tailscale
```

---

## 实施时间表

### 第 1 天：基础设施（4 小时）

**上午（2 小时）：**
- [ ] VPS 端部署 frps
- [ ] 配置防火墙
- [ ] 测试 frp 连接

**下午（2 小时）：**
- [ ] Mac 端安装 frpc
- [ ] 编写 Flask 基础应用（app.py）
- [ ] 测试本地访问

### 第 2 天：核心功能（6 小时）

**上午（3 小时）：**
- [ ] 实现任务管理器（tasks.py）
- [ ] 实现 SSE 日志推送
- [ ] 集成 phone_controller_remote.py

**下午（3 小时）：**
- [ ] 实现 Token 认证（auth.py）
- [ ] 实现配置管理（config.py）
- [ ] 测试任务执行流程

### 第 3 天：前端界面（6 小时）

**上午（3 小时）：**
- [ ] 设计 UI 原型
- [ ] 实现主页（index.html + app.js）
- [ ] 实现任务详情页（task.html）

**下午（3 小时）：**
- [ ] 实现历史记录页（history.html）
- [ ] 移动端适配（响应式设计）
- [ ] 测试前端交互

### 第 4 天：安全和部署（4 小时）

**上午（2 小时）：**
- [ ] Nginx 配置优化
- [ ] 申请 SSL 证书
- [ ] 配置请求限速

**下午（2 小时）：**
- [ ] 编写部署文档
- [ ] 编写使用手册
- [ ] 端到端测试

### 第 5 天：测试和优化（4 小时）

**上午（2 小时）：**
- [ ] 功能测试（各种场景）
- [ ] 性能测试（压力测试）
- [ ] 安全测试（漏洞扫描）

**下午（2 小时）：**
- [ ] Bug 修复
- [ ] 文档完善
- [ ] 最终交付

**总计：5 天（24 小时）**

---

## 总结

### 技术亮点

1. **灵活的网络方案**：frp 提供公网访问，Tailscale 作备用
2. **完善的 Web 界面**：实时日志、截图展示、任务管理
3. **安全可靠**：Token + HTTPS + 限速 + 日志脱敏
4. **易于部署**：一键脚本，10 分钟完成部署
5. **可扩展性**：支持多 Mac、多手机、任务队列

### 预期效果

- ✅ 用户可在任何地方（咖啡厅、办公室）通过浏览器控制家里手机
- ✅ 任务执行过程可视化（实时日志 + 截图）
- ✅ 安全可靠（Token 认证 + HTTPS 加密）
- ✅ 性能良好（frp 隧道 + Nginx 优化）
- ✅ 易于维护（systemd 服务 + 日志审计）

### 下一步行动

**如果您同意此方案，我将：**
1. 创建项目文件结构
2. 编写核心代码（app.py、tasks.py、auth.py）
3. 编写部署脚本（install-frps.sh、deploy-web-frp.sh）
4. 编写前端界面（HTML + Vue.js）
5. 编写详细文档（部署指南、使用手册）
6. 进行测试和优化

**请告知：**
- 是否同意此方案？
- 是否有需要调整的部分？
- 是否立即开始实施？

---

**文档版本：** 2.0.0
**最后更新：** 2026-01-28
**分析师：** Claude Code
