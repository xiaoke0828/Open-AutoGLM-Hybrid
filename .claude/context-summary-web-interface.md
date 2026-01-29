# 项目上下文摘要（Web 端界面需求）
生成时间：2026-01-28

## 1. 现有架构分析

### 1.1 当前部署方案
项目支持两种部署架构：

**方案 A：纯手机端（Termux）**
- 所有组件运行在手机上
- Termux 运行 Python + Open-AutoGLM
- 调用 GRS AI 进行视觉理解和任务规划
- 通过 localhost HTTP 控制手机

**方案 B：Mac 服务器（推荐）**
- Mac 运行 Open-AutoGLM 和 AI 服务
- 手机只运行轻量级 AutoGLM Helper
- 通过 Tailscale 或局域网连接
- 性能更强，随时随地可用

### 1.2 核心组件

**Android 应用（AutoGLM Helper）**
- 位置：`android-app/app/src/main/java/com/autoglm/helper/`
- 技术栈：Kotlin + AccessibilityService + NanoHTTPD
- HTTP API 端口：8080
- 核心端点：
  - `POST /tap` - 点击操作
  - `POST /swipe` - 滑动操作
  - `POST /input` - 输入文字
  - `GET /screenshot` - 获取截图
  - `GET /status` - 服务状态

**Mac 服务器控制器**
- 位置：`mac-server/phone_controller_remote.py`
- 技术栈：Python 3 + requests + Pillow
- 功能：通过 HTTP 请求控制手机
- 支持：局域网和 Tailscale 远程连接

**Termux 控制器**
- 位置：`termux-scripts/phone_controller.py`
- 自动降级逻辑：无障碍服务 → LADB → 错误
- 统一 API 接口

### 1.3 通信架构

```
当前架构（Mac 服务器方案）：
用户 → Mac 命令行 → Open-AutoGLM → GRS AI
                   ↓
            phone_controller_remote.py
                   ↓ HTTP (Tailscale/LAN)
           手机 AutoGLM Helper (8080)
                   ↓ AccessibilityService
              手机执行操作
```

### 1.4 现有技术栈
- **后端**：Python 3
- **HTTP 客户端**：requests
- **图像处理**：Pillow (PIL)
- **AI 服务**：GRS AI (通过 openai 客户端)
- **网络穿透**：Tailscale

## 2. Web 端需求分析

### 2.1 核心需求
1. **手机浏览器访问 Mac 服务器的 Web 界面**
2. **通过界面发布任务给 Open-AutoGLM**
3. **支持远程访问**（Mac 在家，用户在外）

### 2.2 关键场景
- 场景 1：用户在办公室，通过手机浏览器访问家里的 Mac，发布任务控制家里的另一台手机
- 场景 2：用户在咖啡厅，通过 Tailscale 访问家里的 Mac，查看任务执行状态
- 场景 3：用户想批量执行多个任务，通过 Web 界面管理任务队列

### 2.3 功能需求拆解

**基础功能（MVP）**
1. 任务提交界面（输入框 + 提交按钮）
2. 任务状态显示（执行中/完成/失败）
3. 实时日志输出（WebSocket 或 SSE）
4. 手机截图显示（实时预览）

**进阶功能**
5. 任务队列管理（查看、取消、重试）
6. 历史任务记录
7. 用户认证（账号密码或 Token）
8. 多手机管理（如果有多台手机）

**高级功能**
9. 任务模板（预设常用任务）
10. 可视化操作编辑器（录制操作序列）
11. 定时任务
12. Webhook 通知

## 3. 技术栈选择

### 3.1 后端 Web 框架对比

| 框架 | 优势 | 劣势 | 适合度 |
|------|------|------|--------|
| **Flask** | 轻量级、易学、灵活 | 缺少内置功能 | ⭐⭐⭐⭐⭐ |
| FastAPI | 现代、异步、自动文档 | 学习曲线稍陡 | ⭐⭐⭐⭐ |
| Django | 功能完整、ORM 强大 | 过于重量级 | ⭐⭐ |
| Tornado | 异步、WebSocket 支持好 | 生态较小 | ⭐⭐⭐ |

**推荐：Flask**
- 理由：
  1. 轻量级，易于集成到现有项目
  2. 丰富的扩展（Flask-SocketIO、Flask-Login）
  3. 学习曲线平缓，文档完善
  4. 与现有 Python 代码无缝集成

### 3.2 前端技术选择

| 方案 | 优势 | 劣势 | 适合度 |
|------|------|------|--------|
| **Vue.js (CDN)** | 轻量、易学、渐进式 | 无需构建步骤 | ⭐⭐⭐⭐⭐ |
| React | 生态丰富、组件化 | 需要构建工具 | ⭐⭐⭐ |
| 原生 JS + 模板 | 零依赖、简单 | 开发效率低 | ⭐⭐⭐⭐ |
| Alpine.js | 超轻量、声明式 | 功能有限 | ⭐⭐⭐⭐ |

**推荐：Vue.js (CDN 版本) + Tailwind CSS (CDN)**
- 理由：
  1. 无需构建步骤，单 HTML 文件即可运行
  2. 响应式数据绑定，开发效率高
  3. 移动端适配好
  4. Tailwind CSS 提供美观的 UI 组件

### 3.3 实时通信方案

| 方案 | 优势 | 劣势 | 适合度 |
|------|------|------|--------|
| **Server-Sent Events (SSE)** | 简单、单向推送 | 仅服务器推送 | ⭐⭐⭐⭐⭐ |
| WebSocket | 双向通信、低延迟 | 复杂度高 | ⭐⭐⭐⭐ |
| 轮询 | 最简单 | 延迟高、资源浪费 | ⭐⭐ |

**推荐：Server-Sent Events (SSE)**
- 理由：
  1. 日志输出是单向流，SSE 最适合
  2. 原生浏览器支持，无需额外库
  3. 自动重连机制
  4. 实现简单（Flask 直接支持）

## 4. 与现有 Open-AutoGLM 集成

### 4.1 集成方式

**方案 A：进程包装（推荐）**
```python
# Web 服务器启动 Open-AutoGLM 进程
# 通过 subprocess 管道捕获输出
# 通过 SSE 推送给前端
```

**优势：**
- 无需修改 Open-AutoGLM 源码
- 解耦，易于维护
- 可以管理多个任务实例

**劣势：**
- 进程管理复杂度
- 需要处理进程间通信

**方案 B：直接集成**
```python
# 将 Open-AutoGLM 作为 Python 模块导入
# 直接调用其 API
```

**优势：**
- 性能更好
- 错误处理更精确

**劣势：**
- 需要了解 Open-AutoGLM 内部实现
- 耦合度高
- 异步处理复杂

**推荐：方案 A（进程包装）**

### 4.2 任务管理架构

```python
# 任务队列结构
Task {
    id: UUID
    status: 'pending' | 'running' | 'completed' | 'failed'
    command: str (用户输入的任务描述)
    created_at: datetime
    started_at: datetime?
    completed_at: datetime?
    logs: List[str] (实时日志)
    screenshots: List[Image] (执行过程截图)
    result: dict (执行结果)
}

# 使用 Python 队列
import queue
import threading

task_queue = queue.Queue()
active_tasks = {}  # task_id -> Task
history = []  # 已完成任务
```

## 5. 安全性考虑

### 5.1 远程访问安全

**现状：**
- 手机 HTTP 服务仅监听 localhost
- Mac 服务器通过 Tailscale 访问手机
- 无身份验证机制

**Web 端新增风险：**
1. **Web 界面暴露到网络**
   - 风险：任何人可访问和控制
   - 缓解：Tailscale 网络隔离 + 身份验证

2. **未授权任务执行**
   - 风险：恶意用户发布危险任务
   - 缓解：Token 认证 + CSRF 保护

3. **日志泄露敏感信息**
   - 风险：任务日志可能包含密码等
   - 缓解：日志脱敏 + 访问控制

### 5.2 安全方案

**第一阶段（MVP）：Tailscale + 简单 Token**
```python
# 环境变量设置 Token
export WEB_AUTH_TOKEN="random_secure_token_here"

# HTTP Header 验证
Authorization: Bearer <token>
```

**第二阶段：完整认证系统**
- Flask-Login + Session
- 账号密码登录
- 会话过期机制

**第三阶段：高级安全**
- HTTPS (Let's Encrypt)
- OAuth 2.0 (Google/GitHub 登录)
- IP 白名单

### 5.3 Tailscale 安全配置

```bash
# 仅允许 Tailscale 网络访问
# Flask 绑定到 Tailscale IP
tailscale_ip = "100.64.0.1"
app.run(host=tailscale_ip, port=5000)

# 或使用 ACL 规则
# 在 Tailscale Admin Console 配置
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

## 6. 任务状态追踪和结果展示

### 6.1 状态追踪机制

**实时状态更新（SSE）**
```javascript
// 前端 SSE 连接
const eventSource = new EventSource('/api/tasks/{task_id}/stream');

eventSource.onmessage = (event) => {
  const data = JSON.parse(event.data);

  switch(data.type) {
    case 'log':
      appendLog(data.message);
      break;
    case 'screenshot':
      updateScreenshot(data.image_base64);
      break;
    case 'status':
      updateStatus(data.status);
      break;
    case 'completed':
      onTaskCompleted(data.result);
      break;
  }
};
```

**后端 SSE 推送**
```python
@app.route('/api/tasks/<task_id>/stream')
def task_stream(task_id):
    def generate():
        task = active_tasks.get(task_id)
        while task.status in ['pending', 'running']:
            # 推送日志
            if task.has_new_logs():
                yield f"data: {json.dumps({'type': 'log', 'message': task.get_new_log()})}\n\n"

            # 推送截图
            if task.has_new_screenshot():
                yield f"data: {json.dumps({'type': 'screenshot', 'image_base64': task.get_screenshot()})}\n\n"

            time.sleep(0.5)

        # 任务完成
        yield f"data: {json.dumps({'type': 'completed', 'result': task.result})}\n\n"

    return Response(generate(), mimetype='text/event-stream')
```

### 6.2 结果展示

**任务详情页面**
- 任务 ID 和命令
- 状态标签（运行中/成功/失败）
- 执行时间（开始/结束/耗时）
- 实时日志（自动滚动）
- 截图轮播（显示执行过程）
- 执行结果（JSON 展开）

**历史记录页面**
- 任务列表（分页）
- 状态筛选
- 时间排序
- 快速重试按钮

## 7. 实现步骤

### 阶段 0：准备工作
- [x] 分析现有架构
- [x] 确定技术栈
- [x] 设计安全方案

### 阶段 1：基础 Web 服务器（1-2 天）
- [ ] 创建 Flask 应用结构
- [ ] 实现任务提交 API
- [ ] 集成 phone_controller_remote.py
- [ ] 实现基础 Token 认证
- [ ] 测试端到端流程

### 阶段 2：任务管理和状态追踪（1-2 天）
- [ ] 实现任务队列（Python queue）
- [ ] 实现 SSE 实时推送
- [ ] 集成 Open-AutoGLM 进程管理
- [ ] 实现日志捕获和推送
- [ ] 实现截图捕获和推送

### 阶段 3：前端界面（1-2 天）
- [ ] 设计 UI 原型
- [ ] 实现任务提交表单
- [ ] 实现实时日志显示
- [ ] 实现截图轮播
- [ ] 实现任务列表页面
- [ ] 移动端适配

### 阶段 4：安全和部署（1 天）
- [ ] Tailscale 配置优化
- [ ] 身份验证强化
- [ ] 日志脱敏
- [ ] 部署脚本
- [ ] 文档编写

### 阶段 5：测试和优化（1 天）
- [ ] 端到端测试
- [ ] 并发任务测试
- [ ] 远程访问测试
- [ ] 性能优化
- [ ] Bug 修复

**总计：5-7 天**

## 8. 可复用组件清单

### 8.1 现有代码复用
- `mac-server/phone_controller_remote.py` → Web 服务器的手机控制层
- `android-app/` → 无需修改，继续作为执行端
- `docs/TAILSCALE_GUIDE.md` → 参考 Tailscale 配置

### 8.2 新增组件
- `web-server/` → 新目录
  - `app.py` → Flask 应用主文件
  - `tasks.py` → 任务管理逻辑
  - `auth.py` → 身份验证
  - `templates/` → HTML 模板
    - `index.html` → 主页（任务提交）
    - `task.html` → 任务详情
    - `history.html` → 历史记录
  - `static/` → 静态资源
    - `app.js` → 前端逻辑（Vue.js）
    - `style.css` → 样式（Tailwind CSS）
  - `requirements.txt` → Python 依赖
  - `config.py` → 配置管理

## 9. 技术选型理由

### 9.1 为什么选择 Flask？
- **轻量级**：最小化依赖，易于集成到现有项目
- **灵活性**：可选择性添加功能（SSE、WebSocket、ORM）
- **生态丰富**：Flask-SocketIO、Flask-Login、Flask-CORS
- **学习曲线平缓**：文档完善，社区活跃
- **与现有代码无缝集成**：都是 Python 生态

### 9.2 为什么选择 Vue.js (CDN)？
- **无构建步骤**：单 HTML 文件即可运行，简化部署
- **渐进式**：可以从简单开始，逐步引入复杂功能
- **响应式**：数据绑定自动更新 UI
- **移动端友好**：适配各种屏幕尺寸

### 9.3 为什么选择 SSE？
- **单向推送**：日志和状态更新是单向流，SSE 最合适
- **原生支持**：浏览器原生 EventSource API
- **自动重连**：网络断开后自动重连
- **实现简单**：Flask 可以直接 yield 字符串

### 9.4 为什么选择 Tailscale？
- **零配置 VPN**：无需配置路由器端口转发
- **端到端加密**：安全性高
- **跨平台**：Mac、iOS、Android 全支持
- **免费额度**：个人使用足够

## 10. 关键风险点

### 10.1 并发问题
- **风险**：多个用户同时提交任务，队列冲突
- **缓解**：使用线程安全的 queue.Queue()，任务串行执行

### 10.2 进程管理
- **风险**：Open-AutoGLM 进程崩溃或僵尸进程
- **缓解**：使用 subprocess.Popen() + 超时机制 + 定期清理

### 10.3 网络延迟
- **风险**：Tailscale 连接不稳定，任务中断
- **缓解**：任务状态持久化，支持断点续传

### 10.4 日志文件膨胀
- **风险**：长时间运行后日志文件过大
- **缓解**：日志轮转（logrotate）+ 定期清理历史任务

### 10.5 移动端兼容性
- **风险**：手机浏览器 SSE 支持不完整
- **缓解**：提供降级方案（轮询）+ 充分测试

## 11. 未来扩展方向

### 11.1 短期（1-3 个月）
- 任务模板功能（预设常用任务）
- 定时任务（cron 表达式）
- Webhook 通知（任务完成后推送）

### 11.2 中期（3-6 个月）
- 可视化操作编辑器（拖拽式任务编排）
- 多手机管理（同时控制多台手机）
- 任务依赖关系（任务 A 完成后执行任务 B）

### 11.3 长期（6-12 个月）
- 录制和回放（记录操作序列）
- 云端同步（跨设备共享任务模板）
- AI 辅助优化（根据历史执行情况优化任务步骤）

## 12. 参考资料

### 12.1 官方文档
- Flask: https://flask.palletsprojects.com/
- Vue.js: https://vuejs.org/
- Tailwind CSS: https://tailwindcss.com/
- Tailscale: https://tailscale.com/kb/

### 12.2 开源项目参考
- GitHub search: "flask task queue" → 查看类似项目实现
- GitHub search: "web based automation dashboard" → UI 设计参考

### 12.3 内部文档
- `ARCHITECTURE.md` → 现有架构设计
- `docs/MAC_SERVER_DEPLOYMENT.md` → Mac 服务器部署
- `docs/TAILSCALE_GUIDE.md` → Tailscale 配置
