# Open-AutoGLM Web 端界面技术方案
版本：1.0.0
日期：2026-01-28
作者：Claude Code

## 目录

1. [需求概述](#需求概述)
2. [架构设计](#架构设计)
3. [技术栈选型](#技术栈选型)
4. [功能设计](#功能设计)
5. [安全方案](#安全方案)
6. [实现计划](#实现计划)
7. [部署方案](#部署方案)
8. [风险与缓解](#风险与缓解)

---

## 需求概述

### 用户故事

**作为** 远程用户
**我想要** 通过手机浏览器访问 Mac 服务器上的 Web 界面
**以便** 发布任务给 Open-AutoGLM 并实时查看执行状态

### 核心场景

1. **场景 1：办公室远程控制**
   - 用户在办公室，Mac 在家里
   - 通过手机浏览器访问 Mac 的 Web 界面
   - 发布任务："打开淘宝搜索蓝牙耳机"
   - 实时查看家里手机的执行过程

2. **场景 2：外出时查看任务状态**
   - 用户在咖啡厅，Mac 在家里
   - 通过 Tailscale 安全连接
   - 查看任务执行日志和截图

3. **场景 3：批量任务管理**
   - 用户想执行多个任务
   - 通过 Web 界面提交任务队列
   - 系统自动串行执行

### 功能需求（按优先级）

#### MVP 功能（第一版必须）
1. 任务提交界面（输入框 + 提交按钮）
2. 任务状态显示（执行中/完成/失败）
3. 实时日志输出（WebSocket 或 SSE）
4. 手机截图显示（实时预览）
5. Token 身份验证（防止未授权访问）

#### 进阶功能（第二版）
6. 任务队列管理（查看、取消、重试）
7. 历史任务记录（分页、搜索）
8. 任务详情页面（执行时间、错误信息）

#### 高级功能（未来）
9. 任务模板（预设常用任务）
10. 定时任务（cron 表达式）
11. Webhook 通知（任务完成推送）
12. 可视化操作编辑器

---

## 架构设计

### 系统架构图

```
┌─────────────────────────────────────────────────────────────┐
│                         用户端                               │
│  ┌────────────┐         ┌────────────┐                      │
│  │ 手机浏览器  │────────▶│  Mac 浏览器 │                      │
│  └────────────┘         └────────────┘                      │
└────────┬───────────────────────┬─────────────────────────────┘
         │ HTTPS (Tailscale)     │ HTTP (Localhost)
         ▼                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    Mac 服务器 (Flask)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Web 服务器   │  │  任务队列     │  │  进程管理器   │      │
│  │  (Flask App) │──│  (queue)     │──│  (subprocess) │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                   │             │
│         ├─ SSE 推送日志     ├─ 任务调度          ├─ 捕获输出   │
│         ├─ Token 验证      ├─ 状态管理          └─ 超时控制   │
│         └─ 静态文件服务                                      │
└────────┬───────────────────────────────────────────────────┘
         │ HTTP (Tailscale/LAN)
         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Android 手机                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         AutoGLM Helper (无障碍服务)                    │   │
│  │  - HTTP Server (8080)                                │   │
│  │  - AccessibilityService                              │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 数据流

#### 任务提交流程
```
1. 用户在浏览器输入任务 → POST /api/tasks
2. Flask 验证 Token → 创建任务对象 → 加入队列
3. 后台线程取出任务 → 启动 Open-AutoGLM 进程
4. 实时捕获进程输出 → 通过 SSE 推送到前端
5. 任务完成 → 更新状态 → 关闭 SSE 连接
```

#### 截图流程
```
1. Open-AutoGLM 需要截图 → 调用 phone_controller
2. phone_controller 请求 GET /screenshot → AutoGLM Helper
3. AutoGLM Helper 截图 → 返回 Base64 图片
4. phone_controller 解码 → 保存到任务对象
5. Flask 通过 SSE 推送截图数据 → 前端显示
```

### 目录结构

```
web-server/
├── app.py                    # Flask 主应用
├── tasks.py                  # 任务队列管理
├── auth.py                   # Token 认证中间件
├── config.py                 # 配置管理
├── utils.py                  # 工具函数
├── requirements.txt          # Python 依赖
├── deploy-web.sh             # 部署脚本
├── start-web.sh              # 启动脚本
├── templates/                # HTML 模板
│   ├── base.html             # 基础模板
│   ├── index.html            # 主页（任务提交）
│   ├── task.html             # 任务详情页
│   └── history.html          # 历史记录页
├── static/                   # 静态资源
│   ├── js/
│   │   └── app.js            # Vue.js 应用
│   ├── css/
│   │   └── style.css         # 自定义样式
│   └── images/
│       └── logo.png          # Logo
└── logs/                     # 日志文件
    ├── flask.log             # Flask 日志
    └── tasks.log             # 任务执行日志
```

---

## 技术栈选型

### 后端：Flask

**选择理由：**
- ✅ 轻量级，易于集成到现有 Python 项目
- ✅ 丰富的扩展（Flask-CORS、Flask-Login）
- ✅ 原生支持 SSE（Server-Sent Events）
- ✅ 学习曲线平缓，文档完善
- ✅ 与现有 `phone_controller_remote.py` 无缝集成

**替代方案对比：**

| 框架 | 优势 | 劣势 | 适合度 |
|------|------|------|--------|
| **Flask** | 轻量、灵活、SSE 支持好 | 缺少内置 ORM | ⭐⭐⭐⭐⭐ |
| FastAPI | 现代、异步、自动文档 | 学习曲线陡 | ⭐⭐⭐⭐ |
| Django | 功能完整、ORM 强大 | 过于重量级 | ⭐⭐ |

**依赖清单（requirements.txt）：**
```txt
Flask==3.0.0
Flask-CORS==4.0.0
requests==2.31.0
Pillow==10.1.0
python-dotenv==1.0.0
```

### 前端：Vue.js 3 (CDN) + Tailwind CSS

**选择理由：**
- ✅ 无需构建步骤，单 HTML 文件即可运行
- ✅ 响应式数据绑定，开发效率高
- ✅ 移动端友好（响应式设计）
- ✅ CDN 引入，零配置

**技术组合：**
```html
<!-- Vue.js 3 -->
<script src="https://unpkg.com/vue@3/dist/vue.global.js"></script>

<!-- Tailwind CSS -->
<script src="https://cdn.tailwindcss.com"></script>

<!-- Axios (HTTP 客户端) -->
<script src="https://unpkg.com/axios/dist/axios.min.js"></script>
```

### 实时通信：Server-Sent Events (SSE)

**选择理由：**
- ✅ 日志输出是单向流，SSE 最适合
- ✅ 原生浏览器支持（EventSource API）
- ✅ 自动重连机制
- ✅ Flask 直接支持（yield 即可）

**对比 WebSocket：**

| 特性 | SSE | WebSocket |
|------|-----|-----------|
| 通信方向 | 单向（服务器→客户端） | 双向 |
| 实现复杂度 | 简单 | 复杂 |
| 浏览器支持 | 原生 EventSource | 原生 WebSocket |
| 适用场景 | 日志推送、状态更新 | 聊天、游戏 |

**SSE 示例代码：**
```python
# Flask 后端
@app.route('/api/tasks/<task_id>/stream')
def task_stream(task_id):
    def generate():
        while task.is_running():
            yield f"data: {json.dumps({'type': 'log', 'message': task.get_log()})}\n\n"
            time.sleep(0.5)
    return Response(generate(), mimetype='text/event-stream')

# 前端 JavaScript
const eventSource = new EventSource(`/api/tasks/${taskId}/stream`);
eventSource.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log(data.message);
};
```

### 网络穿透：Tailscale

**选择理由：**
- ✅ 零配置 VPN，无需端口转发
- ✅ 端到端加密，安全性高
- ✅ 跨平台（Mac、iOS、Android）
- ✅ 免费额度足够个人使用

**配置示例：**
```python
# Flask 绑定到 Tailscale IP
import subprocess

tailscale_ip = subprocess.check_output(['tailscale', 'ip', '-4']).decode().strip()
app.run(host=tailscale_ip, port=5000)
```

---

## 功能设计

### 1. 任务提交界面

**页面：** `templates/index.html`

**功能：**
- 输入框（多行文本）
- 提交按钮
- 连接状态显示（Mac ✅ / 手机 ✅）

**UI 设计：**
```
┌─────────────────────────────────────┐
│  Open-AutoGLM Web 控制台            │
├─────────────────────────────────────┤
│  连接状态:                           │
│  • Mac 服务器: ✅ 运行中             │
│  • 手机执行端: ✅ 已连接              │
├─────────────────────────────────────┤
│  输入任务:                           │
│  ┌─────────────────────────────┐   │
│  │ 打开淘宝搜索蓝牙耳机          │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│       [提交任务]                    │
├─────────────────────────────────────┤
│  任务队列:                           │
│  1. 打开淘宝... (执行中) 30s        │
│  2. 打开抖音... (等待中)            │
└─────────────────────────────────────┘
```

**Vue.js 代码：**
```javascript
const app = Vue.createApp({
  data() {
    return {
      taskCommand: '',
      tasks: [],
      serverStatus: 'connecting',
      phoneStatus: 'connecting'
    }
  },
  methods: {
    async submitTask() {
      const response = await axios.post('/api/tasks', {
        command: this.taskCommand
      }, {
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('token')}`
        }
      });

      this.tasks.unshift(response.data);
      this.taskCommand = '';

      // 跳转到任务详情页
      window.location.href = `/tasks/${response.data.id}`;
    }
  }
});
app.mount('#app');
```

### 2. 任务详情页

**页面：** `templates/task.html`

**功能：**
- 任务信息（ID、命令、状态、时间）
- 实时日志输出（自动滚动）
- 截图轮播（显示执行过程）
- 操作按钮（取消、重试）

**UI 设计：**
```
┌─────────────────────────────────────┐
│  任务详情 #12345                     │
├─────────────────────────────────────┤
│  命令: 打开淘宝搜索蓝牙耳机           │
│  状态: 🟢 执行中                     │
│  开始时间: 2026-01-28 14:30:00      │
│  已运行: 45 秒                       │
├─────────────────────────────────────┤
│  手机截图:                           │
│  ┌───────────────────────────┐     │
│  │                           │     │
│  │   [手机屏幕截图预览]       │     │
│  │                           │     │
│  └───────────────────────────┘     │
├─────────────────────────────────────┤
│  执行日志:                           │
│  ┌─────────────────────────────┐   │
│  │ [14:30:00] 任务开始          │   │
│  │ [14:30:02] 截取屏幕...       │   │
│  │ [14:30:05] 识别淘宝图标...   │   │
│  │ [14:30:07] 点击淘宝 (120,50) │   │
│  │ [14:30:10] 等待应用打开...   │   │
│  │ ▋                           │   │
│  └─────────────────────────────┘   │
│       [取消任务]  [刷新]            │
└─────────────────────────────────────┘
```

**SSE 日志推送代码：**
```javascript
const eventSource = new EventSource(`/api/tasks/${taskId}/stream`);

eventSource.addEventListener('log', (event) => {
  const data = JSON.parse(event.data);
  this.logs.push(data.message);
  this.$nextTick(() => {
    // 自动滚动到底部
    this.$refs.logContainer.scrollTop = this.$refs.logContainer.scrollHeight;
  });
});

eventSource.addEventListener('screenshot', (event) => {
  const data = JSON.parse(event.data);
  this.screenshots.push(data.image_base64);
});

eventSource.addEventListener('completed', (event) => {
  this.status = 'completed';
  eventSource.close();
});
```

### 3. 历史记录页

**页面：** `templates/history.html`

**功能：**
- 任务列表（分页）
- 状态筛选（全部/成功/失败）
- 时间排序（最新/最早）
- 快速重试按钮

**UI 设计：**
```
┌─────────────────────────────────────┐
│  历史任务                            │
├─────────────────────────────────────┤
│  筛选: [全部] [成功] [失败]          │
│  排序: [最新优先]                    │
├─────────────────────────────────────┤
│  #12345  打开淘宝...   ✅ 成功       │
│  2026-01-28 14:30  耗时: 1m 23s     │
│                      [查看] [重试]   │
├─────────────────────────────────────┤
│  #12344  打开抖音...   ❌ 失败       │
│  2026-01-28 14:25  耗时: 45s        │
│                      [查看] [重试]   │
├─────────────────────────────────────┤
│  #12343  发送微信...   ✅ 成功       │
│  2026-01-28 14:20  耗时: 30s        │
│                      [查看] [重试]   │
├─────────────────────────────────────┤
│       [ 1 ] 2  3  4  5 ... 10       │
└─────────────────────────────────────┘
```

---

## 安全方案

### 1. 网络隔离（Tailscale）

**目标：** 仅允许授权用户通过 Tailscale 网络访问

**实现：**
```python
# config.py
import subprocess

def get_tailscale_ip():
    try:
        result = subprocess.check_output(['tailscale', 'ip', '-4'])
        return result.decode().strip()
    except Exception:
        return '127.0.0.1'  # 降级到本地

FLASK_HOST = get_tailscale_ip()
FLASK_PORT = 5000
```

**Tailscale ACL 配置：**
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["user@example.com"],
      "dst": ["mac-server:5000"]
    }
  ]
}
```

### 2. Token 身份验证

**目标：** 防止未授权访问

**实现：**
```python
# auth.py
from functools import wraps
from flask import request, jsonify
import os

AUTH_TOKEN = os.getenv('WEB_AUTH_TOKEN', 'default_insecure_token')

def require_token(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        token = request.headers.get('Authorization', '').replace('Bearer ', '')

        if token != AUTH_TOKEN:
            return jsonify({'error': 'Unauthorized'}), 401

        return f(*args, **kwargs)
    return decorated_function

# 使用
@app.route('/api/tasks', methods=['POST'])
@require_token
def create_task():
    ...
```

**Token 生成：**
```bash
# 生成随机 Token
python -c "import secrets; print(secrets.token_urlsafe(32))"

# 保存到环境变量
export WEB_AUTH_TOKEN="your_secure_token_here"
```

**前端存储：**
```javascript
// 登录时保存 Token
localStorage.setItem('token', 'your_token_here');

// 每次请求时携带
axios.defaults.headers.common['Authorization'] = `Bearer ${localStorage.getItem('token')}`;
```

### 3. HTTPS 支持（可选）

**使用 Let's Encrypt 自签名证书：**
```bash
# 安装 mkcert
brew install mkcert

# 生成本地证书
mkcert -install
mkcert localhost 100.64.0.1

# Flask 使用 HTTPS
app.run(
    host='100.64.0.1',
    port=5000,
    ssl_context=('localhost+1.pem', 'localhost+1-key.pem')
)
```

### 4. 日志脱敏

**目标：** 防止日志泄露敏感信息（密码、Token）

**实现：**
```python
# utils.py
import re

SENSITIVE_PATTERNS = [
    (r'password["\']?\s*[:=]\s*["\']?(\S+)', 'password: ***'),
    (r'token["\']?\s*[:=]\s*["\']?(\S+)', 'token: ***'),
    (r'\d{15,19}', '****'),  # 银行卡号
]

def sanitize_log(log: str) -> str:
    """脱敏日志中的敏感信息"""
    for pattern, replacement in SENSITIVE_PATTERNS:
        log = re.sub(pattern, replacement, log, flags=re.IGNORECASE)
    return log
```

### 5. 速率限制（防 DDoS）

**使用 Flask-Limiter：**
```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

@app.route('/api/tasks', methods=['POST'])
@limiter.limit("10 per minute")
@require_token
def create_task():
    ...
```

---

## 实现计划

### 阶段 1：基础 Web 服务器（1-2 天）

**目标：** 搭建 Flask 应用，实现任务提交 API

**任务清单：**
- [x] 创建项目目录结构
- [ ] 编写 `requirements.txt`
- [ ] 实现 `app.py`（Flask 主应用）
- [ ] 实现 `auth.py`（Token 认证）
- [ ] 实现 `config.py`（配置管理）
- [ ] 测试 API（Postman/curl）

**交付物：**
- `web-server/app.py`
- `web-server/auth.py`
- `web-server/config.py`
- `web-server/requirements.txt`

**验收标准：**
- [ ] `POST /api/tasks` 可以提交任务
- [ ] `GET /api/tasks/<id>` 可以查询任务状态
- [ ] Token 验证生效（无 Token 返回 401）
- [ ] 可以通过 Tailscale IP 访问

**测试命令：**
```bash
# 启动服务器
cd web-server
source venv/bin/activate
export WEB_AUTH_TOKEN="test_token"
python app.py

# 测试 API
curl -X POST http://100.64.0.1:5000/api/tasks \
  -H "Authorization: Bearer test_token" \
  -H "Content-Type: application/json" \
  -d '{"command": "打开淘宝"}'
```

### 阶段 2：任务管理和状态追踪（1-2 天）

**目标：** 实现任务队列和 SSE 实时推送

**任务清单：**
- [ ] 实现 `tasks.py`（任务队列管理）
- [ ] 实现 SSE 端点（`/api/tasks/<id>/stream`）
- [ ] 集成 `phone_controller_remote.py`
- [ ] 实现进程管理（subprocess）
- [ ] 实现日志捕获和推送

**交付物：**
- `web-server/tasks.py`
- SSE 实时推送功能
- 进程管理和日志捕获

**验收标准：**
- [ ] 任务可以排队执行（串行）
- [ ] SSE 可以实时推送日志
- [ ] 任务状态正确更新（pending → running → completed）
- [ ] 进程超时自动终止（5 分钟）

**测试命令：**
```bash
# 提交任务
TASK_ID=$(curl -X POST http://100.64.0.1:5000/api/tasks \
  -H "Authorization: Bearer test_token" \
  -H "Content-Type: application/json" \
  -d '{"command": "打开淘宝"}' | jq -r '.id')

# 监听 SSE
curl -N http://100.64.0.1:5000/api/tasks/$TASK_ID/stream \
  -H "Authorization: Bearer test_token"
```

### 阶段 3：前端界面（1-2 天）

**目标：** 实现 Web 界面，支持移动端访问

**任务清单：**
- [ ] 设计 UI 原型（Figma/Sketch）
- [ ] 实现 `templates/base.html`（基础模板）
- [ ] 实现 `templates/index.html`（主页）
- [ ] 实现 `templates/task.html`（任务详情）
- [ ] 实现 `templates/history.html`（历史记录）
- [ ] 实现 `static/js/app.js`（Vue.js 应用）
- [ ] 实现 `static/css/style.css`（自定义样式）
- [ ] 移动端适配（响应式设计）

**交付物：**
- 完整的前端界面
- 移动端兼容性

**验收标准：**
- [ ] 可以在手机浏览器访问界面
- [ ] 可以提交任务并实时查看日志
- [ ] 可以查看任务历史记录
- [ ] 移动端布局正常（无横向滚动）

**测试设备：**
- iOS Safari（iPhone）
- Android Chrome
- Mac Safari/Chrome（桌面）

### 阶段 4：安全和部署（1 天）

**目标：** 强化安全，编写部署文档

**任务清单：**
- [ ] Tailscale 配置优化（ACL 规则）
- [ ] Token 机制完善（支持轮换）
- [ ] 日志脱敏（正则替换）
- [ ] 编写 `deploy-web.sh`（部署脚本）
- [ ] 编写 `docs/WEB_SERVER_DEPLOYMENT.md`（部署文档）
- [ ] 编写 `docs/WEB_USER_MANUAL.md`（使用手册）

**交付物：**
- `web-server/deploy-web.sh`
- `docs/WEB_SERVER_DEPLOYMENT.md`
- `docs/WEB_USER_MANUAL.md`
- Tailscale ACL 配置示例

**验收标准：**
- [ ] 一键部署脚本测试通过
- [ ] Tailscale 配置正确（仅授权用户可访问）
- [ ] Token 轮换机制测试通过
- [ ] 文档完整（截图 + 步骤）

### 阶段 5：测试和优化（1 天）

**目标：** 端到端测试，性能优化

**测试清单：**
- [ ] 单任务执行（成功、失败、超时）
- [ ] 多任务排队（3 个任务串行执行）
- [ ] 远程访问（Tailscale 连接稳定性）
- [ ] 移动端兼容性（iOS Safari、Android Chrome）
- [ ] 长时间运行（24 小时稳定性）
- [ ] 并发测试（3 用户同时提交）

**性能指标：**
- 任务提交响应时间 < 100ms
- SSE 日志推送延迟 < 500ms
- 内存占用 < 100MB（空闲时）
- CPU 占用 < 10%（空闲时）

**优化项：**
- [ ] 日志轮转（避免文件过大）
- [ ] 任务自动清理（保留最近 100 条）
- [ ] 截图压缩（减少传输时间）
- [ ] SSE 连接池管理

---

## 部署方案

### 一键部署脚本

**文件：** `web-server/deploy-web.sh`

```bash
#!/bin/bash

set -e

echo "================================"
echo "Open-AutoGLM Web 服务器部署脚本"
echo "================================"
echo ""

# 1. 检查 Python 版本
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 未安装"
    echo "请先安装 Python 3: brew install python3"
    exit 1
fi

echo "✅ Python 版本: $(python3 --version)"

# 2. 检查 Tailscale
if ! command -v tailscale &> /dev/null; then
    echo "⚠️ Tailscale 未安装"
    echo "安装 Tailscale 以支持远程访问..."
    brew install tailscale
    sudo tailscale up
fi

echo "✅ Tailscale IP: $(tailscale ip -4)"

# 3. 创建虚拟环境
echo ""
echo "创建 Python 虚拟环境..."
python3 -m venv venv
source venv/bin/activate

# 4. 安装依赖
echo ""
echo "安装 Python 依赖..."
pip install --upgrade pip
pip install -r requirements.txt

# 5. 生成 Token
echo ""
echo "生成身份验证 Token..."
TOKEN=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
echo "export WEB_AUTH_TOKEN=\"$TOKEN\"" > config.env

echo ""
echo "✅ Token 已保存到 config.env"
echo "   请妥善保管，登录时需要使用"

# 6. 创建启动脚本
cat > start-web.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
source config.env
python app.py
EOF

chmod +x start-web.sh

# 7. 完成
echo ""
echo "================================"
echo "✅ 部署完成！"
echo "================================"
echo ""
echo "下一步："
echo "1. 编辑 config.env 配置 API Key 和手机地址"
echo "2. 运行 ./start-web.sh 启动服务器"
echo "3. 浏览器访问: http://$(tailscale ip -4):5000"
echo "4. 登录 Token: $TOKEN"
echo ""
```

### 配置文件示例

**文件：** `web-server/config.env`

```bash
# GRS AI API Key（必填）
export PHONE_AGENT_API_KEY="sk-your-actual-api-key-here"

# 手机 AutoGLM Helper 地址
export PHONE_HELPER_URL="http://192.168.1.100:8080"  # 局域网
# export PHONE_HELPER_URL="http://100.64.0.2:8080"  # Tailscale

# Web 身份验证 Token（自动生成）
export WEB_AUTH_TOKEN="your_secure_token_here"

# Flask 配置
export FLASK_DEBUG="False"
export FLASK_PORT="5000"
export LOG_LEVEL="INFO"
```

### 启动脚本

**文件：** `web-server/start-web.sh`

```bash
#!/bin/bash

cd "$(dirname "$0")"
source venv/bin/activate
source config.env

echo "================================"
echo "Open-AutoGLM Web 服务器"
echo "================================"
echo ""
echo "Tailscale IP: $(tailscale ip -4)"
echo "访问地址: http://$(tailscale ip -4):5000"
echo "Token: $WEB_AUTH_TOKEN"
echo ""
echo "按 Ctrl+C 停止服务器"
echo ""

python app.py
```

---

## 风险与缓解

### 技术风险

#### 1. 并发问题

**风险：** 多用户同时提交任务导致队列冲突

**概率：** 中
**影响：** 高（任务丢失或重复执行）

**缓解措施：**
- 使用线程安全的 `queue.Queue()`
- 任务串行执行（一次只运行一个）
- 加锁保护临界区

**验证方法：**
```python
# 并发测试脚本
import concurrent.futures
import requests

def submit_task(i):
    response = requests.post('http://localhost:5000/api/tasks', ...)
    return response.json()['id']

with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
    task_ids = list(executor.map(submit_task, range(10)))

# 检查是否有重复 ID
assert len(task_ids) == len(set(task_ids))
```

#### 2. 进程管理

**风险：** Open-AutoGLM 进程崩溃或成为僵尸进程

**概率：** 中
**影响：** 高（资源泄露，系统变慢）

**缓解措施：**
- 使用 `subprocess.Popen()` + 超时控制
- 定期检查并清理僵尸进程
- 进程异常时发送通知

**实现：**
```python
import subprocess
import signal

def run_task_with_timeout(command, timeout=300):
    try:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )

        stdout, _ = process.communicate(timeout=timeout)
        return stdout, process.returncode

    except subprocess.TimeoutExpired:
        process.kill()
        raise Exception(f"任务超时 ({timeout}s)")
```

#### 3. 网络延迟

**风险：** Tailscale 连接不稳定，任务执行中断

**概率：** 低
**影响：** 中（用户体验差）

**缓解措施：**
- 任务状态持久化（保存到文件）
- 支持断点续传（任务可恢复）
- 增加连接重试机制

**实现：**
```python
# 任务状态持久化
import json
import os

def save_task_state(task_id, state):
    with open(f'tasks/{task_id}.json', 'w') as f:
        json.dump(state, f)

def load_task_state(task_id):
    if os.path.exists(f'tasks/{task_id}.json'):
        with open(f'tasks/{task_id}.json') as f:
            return json.load(f)
    return None
```

### 安全风险

#### 4. 未授权访问

**风险：** Token 泄露导致任意用户可控制手机

**概率：** 中
**影响：** 极高（隐私泄露，恶意操作）

**缓解措施：**
- Token 定期轮换（每月）
- 增加 IP 白名单（Tailscale ACL）
- 记录所有操作日志（审计）
- 异常登录告警

**实现：**
```python
# IP 白名单
ALLOWED_IPS = ['100.64.0.2', '100.64.0.3']

@app.before_request
def check_ip():
    if request.remote_addr not in ALLOWED_IPS:
        return jsonify({'error': 'Forbidden'}), 403
```

#### 5. 日志泄露

**风险：** 任务日志可能包含敏感信息（密码、Token）

**概率：** 高
**影响：** 中（信息泄露）

**缓解措施：**
- 日志脱敏（正则替换）
- 访问控制（需要 Token）
- 定期清理旧日志

**实现：** 见上文"日志脱敏"部分

### 用户体验风险

#### 6. 移动端兼容性

**风险：** 某些手机浏览器 SSE 支持不稳定

**概率：** 中
**影响：** 中（无法实时查看日志）

**缓解措施：**
- 提供降级方案（轮询）
- 充分测试（iOS、Android）
- 提供"刷新日志"按钮

**降级方案：**
```javascript
// 检测 SSE 支持
if (typeof EventSource !== 'undefined') {
    // 使用 SSE
    const eventSource = new EventSource(...);
} else {
    // 降级到轮询
    setInterval(() => {
        axios.get(`/api/tasks/${taskId}/logs`).then(...);
    }, 2000);
}
```

#### 7. 任务执行时间过长

**风险：** 用户等待焦虑，不知道进度

**概率：** 高
**影响：** 低（用户体验差）

**缓解措施：**
- 实时日志推送（让用户看到进度）
- 进度估算（根据历史任务）
- 超时提示（5 分钟后提示）

**实现：**
```javascript
// 超时提示
setTimeout(() => {
    if (this.status === 'running') {
        this.showWarning('任务执行时间较长，请耐心等待...');
    }
}, 5 * 60 * 1000);  // 5 分钟
```

---

## 总结

### 技术亮点

1. **轻量级架构**：Flask + Vue.js (CDN)，无需复杂构建
2. **实时通信**：SSE 推送日志和截图，用户体验好
3. **安全可靠**：Tailscale + Token 双重保护
4. **移动优先**：响应式设计，手机访问友好
5. **易于部署**：一键脚本，5 分钟完成部署

### 预期效果

- ✅ 用户可以在任何地方通过手机浏览器控制家里的手机
- ✅ 任务执行过程可视化（日志 + 截图）
- ✅ 安全可靠（仅授权用户可访问）
- ✅ 易于使用（直观的 Web 界面）

### 工作量估算

| 阶段 | 工作量 | 交付物 |
|------|--------|--------|
| 阶段 1：基础 Web 服务器 | 1-2 天 | Flask 应用 + API |
| 阶段 2：任务管理和状态追踪 | 1-2 天 | 任务队列 + SSE |
| 阶段 3：前端界面 | 1-2 天 | Web UI + 移动适配 |
| 阶段 4：安全和部署 | 1 天 | 部署脚本 + 文档 |
| 阶段 5：测试和优化 | 1 天 | 测试 + Bug 修复 |
| **总计** | **5-7 天** | **完整 Web 系统** |

### 下一步

请审阅本技术方案，如果同意，我将开始实现。

如有疑问或建议，请告知，我会相应调整方案。

---

**文档版本：** 1.0.0
**最后更新：** 2026-01-28
**作者：** Claude Code
