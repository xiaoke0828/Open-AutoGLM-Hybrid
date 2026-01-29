# Web 界面快速开始指南

> **最新版本 v1.1.0** - 集成完整 AI 规划逻辑（2026-01-29 修复）

---

## 🎯 现在拥有的功能

- ✅ **完整的 AI 视觉分析** - 识别 APP 图标、按钮、文字
- ✅ **智能任务规划** - 多步骤操作自动执行
- ✅ **自然语言理解** - 支持复杂任务描述
- ✅ **实时查看过程** - AI 思考过程、截图、日志
- ✅ **任务历史管理** - 所有任务永久保存
- ✅ **自动降级保护** - AI 模式 ↔ 简单模式

## 📋 修复说明（v1.0 → v1.1）

### ❌ v1.0 的问题（已修复）

之前的 Web 界面**像个智障**，原因是：
- 只有简单测试代码
- 没有 AI 视觉分析
- 只会点击固定坐标 (540, 1000)
- 无法理解自然语言任务

### ✅ v1.1 的改进

现在完全修复，与 Termux 本地部署功能相同：
- 完整的 PhoneAgent 集成
- GRS AI 视觉理解和任务规划
- 智能识别 APP 图标和按钮
- 多步骤任务自动执行

**对比示例**：

```
任务：打开手机淘宝，搜索笔记本电脑

❌ 修复前：
1. 截图
2. 点击屏幕中心 (540, 1000)  ← 固定坐标，错误！
3. 完成

✅ 修复后：
1. 截图并分析屏幕
2. AI 思考：识别淘宝 APP 图标
3. 点击淘宝图标坐标 (x, y)  ← AI 计算的准确坐标
4. 截图并分析（淘宝首页）
5. AI 思考：识别搜索框
6. 点击搜索框
7. 输入"笔记本电脑"
8. 点击搜索按钮
9. 完成
```

## 🚀 快速开始（3 分钟）

### 前提条件

**Mac 电脑**：
- ✅ macOS 10.15+
- ✅ Python 3.9+
- ✅ 项目已克隆

**Android 手机**：
- ✅ Android 7.0+
- ✅ AutoGLM Helper 已安装
- ✅ 无障碍权限已开启
- ✅ 与 Mac 在同一网络

**API 配置**：
- ✅ GRS AI API Key

---

### 步骤 1：配置手机连接（1 分钟）

**查看手机 IP**：

```bash
# 方式 1: 局域网 IP
# 手机 WiFi 设置 → 查看 IP（例如 192.168.1.100）

# 方式 2: Tailscale IP（推荐远程访问）
tailscale status | grep -i phone
# 输出: 100.64.0.2  phone-xiaomi  ...
```

**测试连接**：

```bash
# 替换为您的手机 IP
curl http://192.168.1.100:8080/status

# 预期输出
{"status":"ok","accessibility_enabled":true}
```

---

### 步骤 2：配置环境变量（1 分钟）

```bash
cd ~/Documents/Open-AutoGLM-Hybrid/web-server

# 编辑配置
nano .env
```

**填写配置**（将示例值替换为实际值）：

```bash
# Web 服务配置
WEB_HOST=127.0.0.1
WEB_PORT=8000

# 手机控制器配置
PHONE_HELPER_URL=http://192.168.1.100:8080  # 📝 替换手机 IP

# AI 模型配置
PHONE_AGENT_API_KEY=your_api_key_here       # 📝 替换 API Key
PHONE_AGENT_BASE_URL=https://api.grsai.com/v1
PHONE_AGENT_MODEL=gpt-4-vision-preview
```

**保存**：按 `Ctrl+O` → `Enter` → `Ctrl+X`

---

### 步骤 3：启动服务（1 分钟）

**方式 1：使用启动脚本**（推荐）

```bash
cd ~/Documents/Open-AutoGLM-Hybrid/web-server
chmod +x restart-with-ai.sh
./restart-with-ai.sh
```

**方式 2：手动启动**

```bash
cd ~/Documents/Open-AutoGLM-Hybrid/web-server

# 创建虚拟环境（首次）
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate

# 安装依赖（首次）
pip install flask flask-cors python-dotenv openai pillow requests

# 启动服务器
python app.py
```

**启动成功输出**：

```
============================================================
AutoGLM Web 服务启动
============================================================
  web_host: 127.0.0.1
  web_port: 8000
  phone_helper_url: http://192.168.1.100:8080
  auth_token: YCaz2kybJCVKxCbkxv7eJeqKsLmrXs0vumUH5egsAe0
============================================================
认证 Token: YCaz2kybJCVKxCbkxv7eJeqKsLmrXs0vumUH5egsAe0
访问地址: http://127.0.0.1:8000
============================================================
✅ PhoneAgent 初始化成功  ← 看到这个说明 AI 功能正常
```

---

### 步骤 4：访问 Web 界面

**打开浏览器**：

```bash
# 自动打开
open http://127.0.0.1:8000

# 或手动访问
# 浏览器输入: http://127.0.0.1:8000
```

**输入认证 Token**：
- 复制启动日志中的 Token
- 粘贴到 Web 页面
- 点击"验证"

---

### 步骤 5：测试 AI 功能

**简单任务**：
```
打开淘宝
```

**复杂任务**：
```
打开手机淘宝，搜索蓝牙耳机
```

**查看执行过程**：
- 📸 实时截图
- 💭 AI 思考过程
- 🎯 执行的动作
- 📊 任务状态

---

## 📊 运行状态说明

### ✅ 正常运行（AI 模式）

**日志输出**：
```
✅ PhoneAgent 初始化成功
   - API Base URL: https://api.grsai.com/v1
   - Model: gpt-4-vision-preview
🤖 使用 AI 规划模式
💭 AI 思考: 识别屏幕上的淘宝图标...
🎯 执行动作: tap
📸 已保存截图
```

说明 AI 功能正常工作。

### ⚠️ 简单模式（降级）

**日志输出**：
```
⚠️ AI 功能不可用，将使用简单模式
⚠️ 使用简单模式（无 AI 规划）
```

**原因**：
1. 手机未连接
2. API Key 未配置或无效
3. 网络连接问题

**解决**：参见下方"故障排除"

---

## 🔧 常用命令

### 启动/停止服务

```bash
# 进入目录
cd ~/Documents/Open-AutoGLM-Hybrid/web-server

# 启动服务
./restart-with-ai.sh

# 或手动启动
source venv/bin/activate
python app.py

# 停止服务（Ctrl+C 或）
lsof -i :8000  # 查找进程
kill <PID>     # 停止进程
```

### 查看日志

```bash
# 实时查看
tail -f logs/web-ai.log

# 查看最近 100 行
tail -100 logs/web-ai.log

# 搜索任务
grep "任务 abc12345" logs/web-ai.log
```

### 测试连接

```bash
# 测试手机连接
curl http://YOUR_PHONE_IP:8080/status

# 查看认证 Token
cat .auth_token

# 查看配置
cat .env
```

---

## 🎯 使用示例

### 购物任务

```
打开淘宝搜索无线耳机
打开京东查看购物车
打开拼多多搜索手机壳
```

### 社交任务

```
打开微信，找到张三，发送"今晚聚餐"
打开抖音刷5个视频
打开微博查看热搜
```

### 工具任务

```
打开支付宝查看余额
打开高德地图导航到北京天安门
打开日历查看今天的日程
```

---

## 🛠️ 故障排除

### 问题 1：手机连接失败

**症状**：
```
❌ 手机控制器初始化失败
⚠️ AI 功能不可用，将使用简单模式
```

**解决步骤**：

```bash
# 1. 检查手机 IP
ping YOUR_PHONE_IP

# 2. 检查 AutoGLM Helper 是否运行
# 打开手机上的 AutoGLM Helper APP

# 3. 检查无障碍权限
# 设置 → 辅助功能 → AutoGLM Helper → 开启

# 4. 测试手机服务
curl -v http://YOUR_PHONE_IP:8080/status

# 5. 更新配置
cd web-server
nano .env
# 修改 PHONE_HELPER_URL 为正确的 IP

# 6. 重启服务
./restart-with-ai.sh
```

---

### 问题 2：端口被占用

**症状**：
```
Address already in use (Port 8000)
```

**解决步骤**：

```bash
# 方式 1: 关闭占用进程
lsof -i :8000
kill <PID>

# 方式 2: 修改端口
cd web-server
nano .env
# 修改 WEB_PORT=9000
```

---

### 问题 3：API Key 无效

**症状**：
```
❌ 任务执行失败
模型错误: Invalid API Key
```

**解决步骤**：

```bash
# 1. 验证 API Key
curl https://api.grsai.com/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"

# 2. 更新配置
cd web-server
nano .env
# 修改 PHONE_AGENT_API_KEY

# 3. 重启服务
./restart-with-ai.sh
```

---

### 问题 4：Python 依赖缺失

**症状**：
```
ModuleNotFoundError: No module named 'flask'
```

**解决步骤**：

```bash
cd web-server
source venv/bin/activate
pip install flask flask-cors python-dotenv openai pillow requests
```

---

### 问题 5：任务卡住不动

**症状**：
- 任务状态一直是"进行中"
- 没有新的日志输出

**解决步骤**：

```bash
# 1. 查看详细日志
tail -f logs/web-ai.log

# 2. 检查手机连接
curl http://YOUR_PHONE_IP:8080/status

# 3. 重启服务
./restart-with-ai.sh
```

---

## 📚 相关文档

- **[AI 功能详细说明](docs/WEB_AI_GUIDE.md)** - AI 功能的完整说明和修复前后对比
- **[腾讯云部署指南](docs/TENCENT_CLOUD_DEPLOYMENT.md)** - 云服务器部署步骤
- **[Tailscale 配置指南](docs/TAILSCALE_GUIDE.md)** - 远程访问配置
- **[frp 内网穿透](docs/FRP_WEB_DEPLOYMENT.md)** - 公网访问配置

---

## 💡 使用技巧

### 提高成功率

1. **清晰的任务描述**
   - ✅ 好：`打开淘宝，搜索蓝牙耳机`
   - ❌ 差：`淘宝`

2. **一次一个任务**
   - ✅ 好：先"打开淘宝"，完成后再"搜索商品"
   - ❌ 差：`打开淘宝、拼多多、京东并搜索商品`

3. **等待任务完成**
   - 不要同时提交多个任务
   - 等待上一个完成后再提交下一个

### 监控和调试

```bash
# 实时查看日志
tail -f web-server/logs/web-ai.log

# 查看任务历史
cat web-server/task_history.json | jq '.'

# 检查服务器状态
curl http://127.0.0.1:8000/api/current-task
```

---

## 🎉 成功示例

**终端日志输出**：
```
2026-01-29 15:50:28 - tasks - INFO - ✅ PhoneAgent 初始化成功
2026-01-29 15:50:30 - tasks - INFO - 任务 abc12345: 🤖 使用 AI 规划模式
2026-01-29 15:50:30 - tasks - INFO - 任务 abc12345: 正在分析任务...
2026-01-29 15:50:35 - tasks - INFO - 任务 abc12345: 💭 AI 思考: 识别屏幕上的淘宝图标
2026-01-29 15:50:35 - tasks - INFO - 任务 abc12345: 🎯 执行动作: tap
2026-01-29 15:50:40 - tasks - INFO - 任务 abc12345: ✅ 已完成
```

**Web 界面显示**：
- 实时日志滚动
- 截图自动更新
- AI 思考过程清晰可见
- 任务状态实时更新

---

## 📞 需要帮助？

遇到问题时：

1. **查看日志**：`tail -f web-server/logs/web-ai.log`
2. **参考文档**：`docs/WEB_AI_GUIDE.md`
3. **检查配置**：`cat web-server/.env`
4. **测试连接**：`curl http://YOUR_PHONE_IP:8080/status`
5. **提交 Issue**：https://github.com/xiaoke0828/Open-AutoGLM-Hybrid/issues

---

**祝您使用愉快！🚀**
