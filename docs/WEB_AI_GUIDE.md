# Web 界面 AI 增强版使用指南

## 🎉 修复完成！

Web 界面现已集成完整的 AI 规划逻辑，与 Termux 本地部署功能相同！

---

## 📊 修复前后对比

### ❌ 修复前（v1.0）

**问题**：
- 只有简单的测试代码
- 无法理解自然语言任务
- 只能点击固定坐标（屏幕中心）
- 没有 AI 视觉分析

**示例**：
```
任务：打开手机淘宝，搜索笔记本电脑

执行：
1. 截图
2. 点击屏幕中心 (540, 1000)  ← 固定坐标
3. 完成

结果：像智障，没有真正打开淘宝
```

### ✅ 修复后（v1.1）

**功能**：
- 完整的 AI 规划逻辑
- 理解自然语言任务
- 智能识别 APP 图标和按钮
- 多步骤任务规划

**示例**：
```
任务：打开手机淘宝，搜索笔记本电脑

执行：
1. 截图并分析屏幕
2. AI 思考：识别淘宝 APP 图标
3. 点击淘宝图标坐标 (x, y)  ← AI 计算的准确坐标
4. 截图并分析（淘宝首页）
5. AI 思考：识别搜索框
6. 点击搜索框坐标
7. 输入"笔记本电脑"
8. AI 思考：识别搜索按钮
9. 点击搜索按钮
10. 完成

结果：真正完成了任务！
```

---

## 🚀 快速开始

### 步骤1：更新代码

```bash
cd ~/Documents/Open-AutoGLM-Hybrid
git pull origin main
```

### 步骤2：配置环境变量

编辑 `web-server/.env` 文件：

```bash
cd web-server
nano .env
```

确保包含以下配置：

```bash
# Web 服务配置
WEB_HOST=127.0.0.1
WEB_PORT=8000

# 手机控制器配置
PHONE_HELPER_URL=http://YOUR_PHONE_IP:8080  # 替换为您的手机 IP

# AI 模型配置（GRS AI / OpenAI 兼容）
PHONE_AGENT_API_KEY=your_api_key_here        # 替换为您的 API Key
PHONE_AGENT_BASE_URL=https://api.grsai.com/v1
PHONE_AGENT_MODEL=gpt-4-vision-preview
```

**获取手机 IP**：
- 方法1（推荐）：使用 Tailscale
  - 手机上查看 Tailscale APP，IP 通常是 `100.x.x.x`
  - 示例：`PHONE_HELPER_URL=http://100.64.0.2:8080`

- 方法2：使用局域网 IP
  - 手机 WiFi 设置中查看 IP
  - 示例：`PHONE_HELPER_URL=http://192.168.1.100:8080`

### 步骤3：启动服务器

```bash
cd web-server
source venv/bin/activate  # 激活虚拟环境
python app.py
```

或使用启动脚本：

```bash
./restart-with-ai.sh
```

### 步骤4：访问 Web 界面

打开浏览器，访问：**http://127.0.0.1:8000**

您会看到一个认证 Token，复制它并在页面输入。

---

## 📱 确保手机就绪

在提交任务前，请确保：

1. **AutoGLM Helper APP 已运行**
   - 打开手机上的 AutoGLM Helper 应用

2. **无障碍服务已开启**
   - 设置 → 辅助功能 → 已下载的服务 → AutoGLM Helper → 开启

3. **网络连接正常**
   - 测试命令：`curl http://YOUR_PHONE_IP:8080/status`
   - 预期输出：`{"status":"ok","accessibility_enabled":true}`

---

## 🎯 使用示例

### 示例1：简单任务

**任务**：打开淘宝

**流程**：
1. 在 Web 界面输入：`打开淘宝`
2. 点击"提交任务"
3. 查看实时日志：
   - AI 思考过程
   - 识别的图标和按钮
   - 执行的动作

### 示例2：复杂任务

**任务**：打开手机淘宝，搜索笔记本电脑

**流程**：
1. 输入：`打开手机淘宝，搜索笔记本电脑`
2. AI 自动规划多步操作：
   - 找到并点击淘宝图标
   - 识别搜索框并点击
   - 输入"笔记本电脑"
   - 点击搜索按钮

### 示例3：购物任务

**任务**：在拼多多搜索 iPhone 15

**流程**：
1. 输入：`在拼多多搜索 iPhone 15`
2. AI 完成：
   - 打开拼多多
   - 找到搜索框
   - 输入并搜索

---

## 🔧 故障排除

### 问题1：显示"⚠️ AI 功能不可用，将使用简单模式"

**原因**：
- 手机连接失败
- API Key 未配置

**解决方案**：
1. 检查手机 IP 是否正确
   ```bash
   ping YOUR_PHONE_IP
   curl http://YOUR_PHONE_IP:8080/status
   ```

2. 检查 AutoGLM Helper 是否运行

3. 检查 API Key 是否配置
   ```bash
   cat .env | grep PHONE_AGENT_API_KEY
   ```

### 问题2：任务失败，显示"模型错误"

**原因**：
- API Key 无效
- API 额度不足
- 网络连接失败

**解决方案**：
1. 验证 API Key
   - 登录 GRS AI 官网检查
   - 确认 API Key 有效且有额度

2. 检查网络
   ```bash
   curl https://api.grsai.com/v1/models
   ```

3. 查看详细日志
   ```bash
   tail -f web-server/logs/web-ai.log
   ```

### 问题3：端口被占用

**错误**：`Address already in use (Port 5000 / 8000)`

**解决方案**：
1. 关闭占用端口的程序
   ```bash
   # 查找占用进程
   lsof -i :8000

   # 停止进程
   kill <PID>
   ```

2. 或者修改端口
   ```bash
   # 编辑 .env
   nano .env

   # 修改为其他端口
   WEB_PORT=9000
   ```

### 问题4：手机 IP 无法连接

**Tailscale 方案**（推荐）：
```bash
# 1. 在手机安装 Tailscale
# 2. 在 Mac 安装 Tailscale
brew install tailscale

# 3. 启动 Tailscale
sudo tailscale up

# 4. 查看设备列表
tailscale status

# 5. 找到手机 IP（通常是 100.x.x.x）
# 6. 更新 .env
PHONE_HELPER_URL=http://100.64.0.2:8080
```

**局域网方案**：
```bash
# 1. 确保手机和 Mac 在同一 WiFi
# 2. 查看手机 IP（WiFi 设置）
# 3. 测试连接
ping 192.168.1.100
curl http://192.168.1.100:8080/status

# 4. 更新 .env
PHONE_HELPER_URL=http://192.168.1.100:8080
```

---

## 📊 日志说明

### 成功的 AI 模式日志

```
2026-01-29 15:50:28,629 - tasks - INFO - ✅ PhoneAgent 初始化成功
2026-01-29 15:50:28,629 - tasks - INFO -    - API Base URL: https://api.grsai.com/v1
2026-01-29 15:50:28,629 - tasks - INFO -    - Model: gpt-4-vision-preview
...
2026-01-29 15:50:30,123 - tasks - INFO - 任务 abc12345: 🤖 使用 AI 规划模式
2026-01-29 15:50:30,124 - tasks - INFO - 任务 abc12345: 正在分析任务...
2026-01-29 15:50:35,567 - tasks - INFO - 任务 abc12345: 💭 AI 思考: 识别屏幕上的淘宝图标...
2026-01-29 15:50:35,568 - tasks - INFO - 任务 abc12345: 🎯 执行动作: tap
2026-01-29 15:50:35,890 - tasks - INFO - 任务 abc12345: 📸 已保存截图
```

### 简单模式日志（降级）

```
2026-01-29 15:50:28,629 - tasks - WARNING - ⚠️ AI 功能不可用，将使用简单模式
...
2026-01-29 15:50:30,123 - tasks - INFO - 任务 abc12345: ⚠️ 使用简单模式（无 AI 规划）
2026-01-29 15:50:30,124 - tasks - ERROR - 任务 abc12345: ❌ 无 AI 模式下不支持自然语言任务
```

---

## 🎨 Web 界面功能

### 主页功能
- ✅ 任务提交
- ✅ 最近任务列表
- ✅ 实时任务状态

### 任务详情页
- ✅ 实时日志流
- ✅ AI 思考过程
- ✅ 执行的动作列表
- ✅ 每一步的截图
- ✅ 任务状态（执行中/已完成/失败）

### 任务历史
- ✅ 保存最近 50 个任务
- ✅ 可查看历史任务详情
- ✅ 截图和日志永久保存

---

## 🔐 安全说明

**认证 Token**：
- 每次启动生成唯一 Token
- 保存在 `.auth_token` 文件中
- Web 界面需要输入 Token 才能访问

**API Key 安全**：
- 存储在 `.env` 文件中
- 不要提交到 Git
- 不要分享给他人

**网络安全**：
- 默认只监听 localhost (127.0.0.1)
- 不暴露到公网
- 如需远程访问，使用 Tailscale 或 frp

---

## 📚 相关文档

- [腾讯云服务器部署指南](TENCENT_CLOUD_DEPLOYMENT.md)
- [Tailscale 配置指南](TAILSCALE_GUIDE.md)
- [frp 内网穿透部署](FRP_WEB_DEPLOYMENT.md)
- [常见问题解答](../README.md#常见问题)

---

## 💡 提示和技巧

### 提高成功率
1. 使用清晰的任务描述
   - ✅ 好：`打开淘宝，搜索蓝牙耳机`
   - ❌ 差：`淘宝`

2. 一次一个任务
   - ✅ 好：先"打开淘宝"，再"搜索商品"
   - ❌ 差：`打开淘宝、拼多多、京东并搜索商品`

3. 等待任务完成
   - 不要同时提交多个任务
   - 等上一个任务完成后再提交下一个

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

## 🎉 总结

您的 Web 界面现在拥有完整的 AI 功能！

**核心能力**：
- ✅ AI 视觉分析（识别 APP 图标、按钮、文字）
- ✅ 智能任务规划（多步骤操作）
- ✅ 自然语言理解（支持复杂任务描述）
- ✅ 自动降级（AI 模式 → 简单模式）

**使用流程**：
1. 启动服务器：`python app.py`
2. 访问：http://127.0.0.1:8000
3. 输入任务：`打开淘宝，搜索笔记本电脑`
4. 查看实时日志和截图
5. 等待任务完成

**享受自动化吧！** 🚀
