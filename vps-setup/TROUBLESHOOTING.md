# 公网访问故障排查指南

> 问题：http://193.112.94.2:8080 访问不通

---

## 🔍 问题诊断

### 当前状态检查

**本地检查结果**：
- ❌ 端口 8080 连接超时（nc -zv 193.112.94.2 8080）
- ❌ Mac 端 frpc 未运行（ps aux | grep frpc）

**可能的原因**：
1. VPS 端 frps 未安装或未运行
2. 腾讯云安全组未开放端口
3. Mac 端 frpc 未启动
4. Web 服务器未运行

---

## ✅ 完整修复步骤

### 步骤 1：检查并安装 VPS 端 frps（必须先做）

**SSH 登录到 VPS**：
```bash
ssh root@193.112.94.2
```

**检查 frps 是否已安装**：
```bash
# 检查 frps 服务状态
systemctl status frps

# 如果显示 "Unit frps.service could not be found"
# 说明还没安装，继续下面的步骤
```

**如果未安装，执行安装**：

#### 1.1 上传配置文件（在本地 Mac 执行）

```bash
cd ~/Documents/Open-AutoGLM-Hybrid/vps-setup

# 上传文件
scp frps.ini root@193.112.94.2:/root/
scp install-frps.sh root@193.112.94.2:/root/
```

#### 1.2 安装 frps（在 VPS 上执行）

```bash
# SSH 登录 VPS
ssh root@193.112.94.2

# 执行安装
cd /root
chmod +x install-frps.sh
sudo ./install-frps.sh
```

**预期输出**：
```
✅ frp 服务端安装完成
✅ systemd 服务已启用
✅ frps 正在运行
```

#### 1.3 验证 frps 运行

```bash
# 检查服务状态
sudo systemctl status frps

# 应该看到：Active: active (running)

# 检查端口监听
sudo ss -tuln | grep -E "7000|8080|7500"

# 应该看到：
# tcp   LISTEN  0.0.0.0:7000
# tcp   LISTEN  0.0.0.0:7500
```

**如果端口没有监听**：
```bash
# 查看 frps 日志
sudo tail -50 /var/log/frps.log

# 常见错误：
# - "bind: address already in use" → 端口被占用
# - "permission denied" → 权限问题
```

---

### 步骤 2：配置腾讯云安全组（必须）

**⚠️ 非常重要**：即使 frps 运行正常，如果安全组没开放端口，外网仍然无法访问！

#### 2.1 登录腾讯云控制台

访问：https://console.cloud.tencent.com/cvm/instance

#### 2.2 找到您的 VPS 实例

- 实例 ID：找到 IP 为 `193.112.94.2` 的实例
- 点击实例 ID 进入详情页

#### 2.3 配置安全组

**方式 A：快速配置（推荐）**

1. 点击"安全组"标签页
2. 点击"编辑规则"
3. 点击"入站规则"
4. 点击"添加规则"

**添加以下三条规则**：

```
规则 1：frp 服务端口
-------------------
协议类型: TCP
端口: 7000
来源: 0.0.0.0/0
策略: 允许
备注: frp-server

规则 2：Web 访问端口
-------------------
协议类型: TCP
端口: 8080
来源: 0.0.0.0/0
策略: 允许
备注: web-access

规则 3：Dashboard 端口（可选）
-------------------
协议类型: TCP
端口: 7500
来源: 0.0.0.0/0
策略: 允许
备注: frp-dashboard
```

**方式 B：使用预设模板**

1. 点击"添加规则"
2. 选择"自定义 TCP"
3. 端口输入：`7000,8080,7500`
4. 来源：`0.0.0.0/0`
5. 点击"完成"

#### 2.4 验证安全组配置

**在本地 Mac 测试**：
```bash
# 测试 frp 服务端口
nc -zv 193.112.94.2 7000

# 预期输出：Connection to 193.112.94.2 port 7000 [tcp/*] succeeded!

# 测试 Dashboard 端口
curl -I http://193.112.94.2:7500

# 预期输出：HTTP/1.1 200 OK
```

---

### 步骤 3：检查 Mac 端环境

#### 3.1 检查 frpc 是否已安装

```bash
cd ~/Documents/Open-AutoGLM-Hybrid/web-server

# 检查 frpc 是否存在
ls -lh frpc

# 如果文件不存在，下载安装
```

#### 3.2 下载 frpc（如果需要）

**检查 Mac 架构**：
```bash
uname -m
# arm64 → M1/M2/M3 芯片
# x86_64 → Intel 芯片
```

**下载对应版本**：

```bash
cd ~/Documents/Open-AutoGLM-Hybrid/web-server

# ARM64 (M 芯片 Mac)
curl -L -o frpc.tar.gz https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_darwin_arm64.tar.gz

# 或 AMD64 (Intel Mac)
# curl -L -o frpc.tar.gz https://github.com/fatedier/frp/releases/download/v0.52.3/frp_0.52.3_darwin_amd64.tar.gz

# 解压
tar -xzf frpc.tar.gz
mv frp_*/frpc .
chmod +x frpc
rm -rf frp_* frpc.tar.gz

# 验证
./frpc --version
```

#### 3.3 检查 frpc.ini 配置

```bash
cat frpc.ini

# 应该看到：
# server_addr = 193.112.94.2
# server_port = 7000
# authentication_token = ...
```

---

### 步骤 4：启动 Mac 端服务

#### 4.1 启动 Web 服务器（终端 1）

```bash
cd ~/Documents/Open-AutoGLM-Hybrid/web-server

# 激活虚拟环境
source venv/bin/activate

# 启动服务器
python app.py
```

**预期输出**：
```
✅ 手机控制器初始化成功
✅ PhoneAgent 初始化成功
Running on http://0.0.0.0:8000
```

**验证本地访问**：
```bash
# 新开一个终端测试
curl http://127.0.0.1:8000

# 应该返回 HTML 内容
```

#### 4.2 启动 frpc（终端 2）

```bash
cd ~/Documents/Open-AutoGLM-Hybrid/web-server

# 启动 frpc
./frpc -c frpc.ini
```

**成功的日志输出**：
```
[I] [service.go:XXX] login to server success, get run id [xxx]
[I] [proxy_manager.go:XXX] [web-autoglm] start proxy success
```

**失败的日志输出及解决**：

**错误 1**：`connect to server failed`
```
原因：无法连接到 VPS 的 7000 端口
解决：
1. 检查 VPS 端 frps 是否运行
2. 检查安全组是否开放 7000 端口
3. ping 193.112.94.2 确认网络通畅
```

**错误 2**：`authentication failed`
```
原因：认证 Token 不匹配
解决：
1. 检查 VPS 端 frps.ini 的 authentication_token
2. 检查 Mac 端 frpc.ini 的 authentication_token
3. 确保两者完全一致
```

**错误 3**：`port already used`
```
原因：本地 8000 端口被占用
解决：
1. 检查 Web 服务器是否已运行
2. lsof -i :8000 查看占用进程
```

---

### 步骤 5：测试公网访问

#### 5.1 检查 frp Dashboard

访问：http://193.112.94.2:7500

输入：
- 用户名：`admin`
- 密码：（查看 `web-server/.frp-config`）

**应该看到**：
- ✅ `web-autoglm` 状态：在线（绿色）
- ✅ 连接数：1

**如果看不到或显示离线**：
- Mac 端 frpc 未成功连接
- 查看 frpc 日志排查原因

#### 5.2 测试 Web 访问

**外网访问**：
```
http://193.112.94.2:8080
```

**应该看到**：
- AutoGLM Web 界面
- 要求输入 Token

**如果看到 502 Bad Gateway**：
- Mac 端 Web 服务器未运行
- 检查终端 1 的 `python app.py`

**如果看到连接超时**：
- 安全组未开放 8080 端口
- 或 VPS 端 frps 未运行

---

## 📋 完整检查清单

**在 VPS 上**：
- [ ] frps 已安装并运行（`systemctl status frps`）
- [ ] 端口 7000, 8080, 7500 正在监听（`ss -tuln`）
- [ ] 防火墙允许这些端口（`iptables -L` 或 `ufw status`）

**在腾讯云控制台**：
- [ ] 安全组已添加入站规则（TCP 7000, 8080, 7500）
- [ ] 规则策略为"允许"
- [ ] 来源为 `0.0.0.0/0`

**在 Mac 上**：
- [ ] Web 服务器正在运行（`python app.py`）
- [ ] frpc 已安装（`./frpc --version`）
- [ ] frpc 已连接成功（查看日志）
- [ ] 本地可访问（`curl http://127.0.0.1:8000`）

**网络测试**：
- [ ] 可以 ping 通 VPS（`ping 193.112.94.2`）
- [ ] 7000 端口可连接（`nc -zv 193.112.94.2 7000`）
- [ ] Dashboard 可访问（http://193.112.94.2:7500）
- [ ] Web 可访问（http://193.112.94.2:8080）

---

## 🔧 快速诊断脚本

**保存为 `check-frp.sh` 并执行**：

```bash
#!/bin/bash

echo "=== frp 公网访问诊断 ==="
echo ""

# 检查本地服务
echo "1. 检查本地 Web 服务器..."
curl -s http://127.0.0.1:8000 > /dev/null && echo "✅ Web 服务器运行正常" || echo "❌ Web 服务器未运行"

echo ""
echo "2. 检查本地 frpc 进程..."
ps aux | grep frpc | grep -v grep > /dev/null && echo "✅ frpc 正在运行" || echo "❌ frpc 未运行"

echo ""
echo "3. 测试 VPS 网络连通性..."
ping -c 1 193.112.94.2 > /dev/null 2>&1 && echo "✅ VPS 网络通畅" || echo "❌ 无法连接到 VPS"

echo ""
echo "4. 测试 frp 服务端口（7000）..."
nc -zv -w 3 193.112.94.2 7000 2>&1 | grep -q succeeded && echo "✅ frp 端口可访问" || echo "❌ frp 端口不可达"

echo ""
echo "5. 测试 Web 端口（8080）..."
nc -zv -w 3 193.112.94.2 8080 2>&1 | grep -q succeeded && echo "✅ Web 端口可访问" || echo "❌ Web 端口不可达"

echo ""
echo "6. 测试 Dashboard（7500）..."
curl -s -o /dev/null -w "%{http_code}" http://193.112.94.2:7500 | grep -q 200 && echo "✅ Dashboard 可访问" || echo "❌ Dashboard 不可达"

echo ""
echo "=== 诊断完成 ==="
```

---

## 💡 常见场景和解决方案

### 场景 1：VPS 刚买，什么都没安装

**解决**：
1. SSH 登录 VPS
2. 上传 frps.ini 和 install-frps.sh
3. 执行安装脚本
4. 配置安全组
5. 启动 Mac 端 frpc

### 场景 2：VPS 已安装 frps，但访问不通

**排查**：
1. `systemctl status frps` 检查服务
2. `ss -tuln | grep 7000` 检查端口
3. 检查安全组配置
4. 重启 frps：`systemctl restart frps`

### 场景 3：frpc 启动失败

**排查**：
1. 检查 frpc.ini 配置是否正确
2. 检查 VPS IP 和端口
3. 检查 Token 是否一致
4. 查看详细日志：`./frpc -c frpc.ini -L debug`

---

**需要更多帮助？** 提供以下信息：
1. VPS 端 frps 日志：`sudo tail -50 /var/log/frps.log`
2. Mac 端 frpc 日志输出
3. 安全组配置截图
