# Mac 服务器部署文件

本目录包含在 Mac 电脑上部署 Open-AutoGLM 服务器所需的脚本和文件。

## 文件说明

- **deploy-mac.sh** - 自动部署脚本，安装所有依赖并配置环境
- **phone_controller_remote.py** - 远程手机控制器，通过网络连接到手机的 AutoGLM Helper

## 快速开始

### 1. 准备手机

在 Android 手机上：
1. 安装 AutoGLM Helper APK
2. 启用无障碍权限
3. 记录手机的 IP 地址（在应用中显示）

### 2. 部署服务器

```bash
cd mac-server
./deploy-mac.sh
```

### 3. 配置

编辑配置文件：
```bash
nano ~/autoglm-server/config.env
```

填入：
- GRS AI API Key
- 手机的 IP 地址

### 4. 启动

```bash
cd ~/autoglm-server
./start-server.sh
```

## 架构

```
Mac 电脑 (服务器)
    ├─ Open-AutoGLM (任务规划)
    ├─ GRS AI (视觉理解)
    └─ phone_controller_remote.py
         ↓ HTTP 请求
Android 手机 (执行端)
    └─ AutoGLM Helper (无障碍服务)
```

## 网络连接

### 局域网连接（同一 WiFi）

```bash
# 手机 IP 示例
export PHONE_HELPER_URL="http://192.168.1.100:8080"
```

### 远程连接（Tailscale）

```bash
# 安装 Tailscale
brew install tailscale
sudo tailscale up

# 使用 Tailscale IP
export PHONE_HELPER_URL="http://100.64.0.2:8080"
```

## 测试

### 测试连接

```bash
cd ~/autoglm-server
source config.env
curl $PHONE_HELPER_URL/status
```

### 测试控制器

```bash
cd ~/autoglm-server
source venv/bin/activate
source config.env
python phone_controller_remote.py
```

## 详细文档

- [Mac 服务器完整部署指南](../docs/MAC_SERVER_DEPLOYMENT.md)
- [Tailscale 远程访问配置](../docs/TAILSCALE_GUIDE.md)
- [Mac 快速开始](../QUICK_START_MAC.md)

## 故障排除

### 无法连接到手机

1. 确认手机和 Mac 在同一网络
2. 测试 ping：`ping 192.168.1.100`
3. 测试端口：`nc -zv 192.168.1.100 8080`
4. 确认 AutoGLM Helper 正在运行

### 部署失败

1. 确认 Homebrew 已安装
2. 确认有稳定的网络连接
3. 查看错误日志
4. 手动安装依赖：`brew install python@3.11`

## 工作目录

部署后，所有文件位于：
```
~/autoglm-server/
    ├── venv/               # Python 虚拟环境
    ├── Open-AutoGLM/       # Open-AutoGLM 项目
    ├── config.env          # 配置文件
    └── start-server.sh     # 启动脚本
```

## 维护

### 更新代码

```bash
cd ~/autoglm-server/Open-AutoGLM
git pull origin main
```

### 重新配置

```bash
nano ~/autoglm-server/config.env
```

### 清理并重新部署

```bash
rm -rf ~/autoglm-server
cd mac-server
./deploy-mac.sh
```

## 支持

遇到问题？
- 查看详细文档
- 提交 GitHub Issue
- 附上日志和错误信息

---

**祝您使用愉快！** 🎉
