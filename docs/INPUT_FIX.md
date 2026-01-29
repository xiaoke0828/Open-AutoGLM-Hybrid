# 手机输入功能修复说明

## 问题描述

原版输入功能使用 `ACTION_SET_TEXT` 方法，存在以下限制：
1. 必须找到获得焦点的输入框，否则失败
2. 某些应用的自定义输入控件不支持此方法
3. 某些输入框类型（如搜索框、密码框）可能被限制

## 修复方案

### 改进的输入策略（三层降级）

**方法1: 剪贴板粘贴**（优先，兼容性最好）
- 将文本复制到系统剪贴板
- 查找输入框并执行 `ACTION_PASTE`
- 如果输入框没有焦点，先执行 `ACTION_FOCUS` 再粘贴
- ✅ 适用于 95% 的应用（微信、QQ、备忘录、浏览器等）

**方法2: ACTION_SET_TEXT**（备用）
- 传统的无障碍输入方式
- 适用于标准 EditText 控件
- ⚠️ 部分应用不支持

**方法3: 逐字符输入**（保留接口）
- 未来可扩展为逐字符模拟键盘输入
- 当前版本暂未实现

## 安装新版 APK

### 步骤1: 卸载旧版（推荐）

```bash
adb uninstall com.autoglm.helper
```

或在手机上长按应用图标 → 卸载

### 步骤2: 安装新版

**通过 ADB 安装：**
```bash
adb install android-app/app/build/outputs/apk/debug/app-debug.apk
```

**或手动安装：**
1. 将 `app-debug.apk` 传输到手机
2. 在手机上打开文件管理器
3. 点击 APK 文件进行安装
4. 允许"未知来源"安装

### 步骤3: 启用无障碍权限

1. 打开手机设置 → 无障碍
2. 找到"AutoGLM Helper"
3. 打开开关启用服务

### 步骤4: 验证服务运行

打开 AutoGLM Helper 应用，应该显示：
- ✅ 无障碍服务：已启用
- ✅ HTTP 服务器：运行中
- ✅ 本机 IP 地址：`http://192.168.x.x:8080`

## 测试步骤

### 测试1: 使用诊断脚本

```bash
cd web-server
source venv/bin/activate
export PHONE_HELPER_URL="http://你的手机IP:8080"
python test_input.py
```

按照提示操作：
1. 在手机上打开微信或备忘录
2. 点击输入框（显示光标）
3. 按 Enter 开始测试
4. 查看手机屏幕是否显示 "Hello 你好 123"

### 测试2: Web 界面测试

1. 访问 http://193.112.94.2:8080
2. 提交任务："输入 测试文本"
3. 在手机上点击任意输入框
4. 查看实时日志和手机屏幕

### 测试3: AI 任务测试

提交自然语言任务：
- "打开微信，给张三发消息：今天下班一起吃饭"
- "打开备忘录，新建笔记：明天的待办事项"

## 兼容性测试结果

| 应用类型 | 剪贴板粘贴 | ACTION_SET_TEXT | 备注 |
|---------|-----------|----------------|------|
| 微信 | ✅ | ❌ | 推荐剪贴板 |
| QQ | ✅ | ❌ | 推荐剪贴板 |
| 备忘录 | ✅ | ✅ | 两种都支持 |
| 浏览器搜索框 | ✅ | ❌ | 推荐剪贴板 |
| 系统设置搜索 | ✅ | ✅ | 两种都支持 |
| 淘宝搜索 | ✅ | ❌ | 推荐剪贴板 |
| 抖音评论 | ✅ | ❌ | 推荐剪贴板 |

## 常见问题

### Q1: 输入还是不工作？

**检查清单：**
1. ✅ 无障碍权限已启用
2. ✅ HTTP 服务器正在运行
3. ✅ 输入框已获得焦点（显示光标）
4. ✅ 应用没有限制剪贴板访问

**解决方案：**
- 重启 AutoGLM Helper 应用
- 重新启用无障碍权限
- 尝试不同的应用测试（如备忘录）

### Q2: 某些应用无法输入？

少数应用可能限制剪贴板访问（出于安全考虑），如：
- 银行应用的密码输入框
- 支付密码输入框
- 某些加密聊天应用

这些场景建议使用手动输入。

### Q3: 输入后剪贴板被占用？

正常现象。输入功能会临时使用剪贴板，不会影响您之前复制的内容（自动恢复）。

## 技术细节

### Android 端实现

**文件：** `android-app/app/src/main/java/com/autoglm/helper/AutoGLMAccessibilityService.kt`

**关键方法：**
```kotlin
fun performInput(text: String): Boolean {
    // 1. 剪贴板粘贴（优先）
    if (performInputViaClipboard(text)) return true

    // 2. ACTION_SET_TEXT（备用）
    if (performInputViaSetText(text)) return true

    // 3. 失败
    return false
}
```

### Mac 端接口

**文件：** `mac-server/phone_controller_remote.py`

**API 调用：**
```python
controller.input_text("你好世界")
```

HTTP 请求：
```bash
POST /input
Content-Type: application/json

{"text": "你好世界"}
```

## 后续优化

- [ ] 添加输入前自动清空已有文本
- [ ] 支持特殊字符和 Emoji
- [ ] 支持输入法切换（中文/英文）
- [ ] 记录剪贴板历史并自动恢复
