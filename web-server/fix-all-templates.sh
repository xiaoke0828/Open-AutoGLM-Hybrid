#!/bin/bash

# ================================
# 修复所有模板文件的语法冲突
# ================================

set -e

cd "$(dirname "$0")"

echo "======================================"
echo "修复所有模板文件"
echo "======================================"
echo ""

# 备份
echo "📦 备份原文件..."
cp templates/task.html templates/task.html.backup 2>/dev/null || true
cp templates/history.html templates/history.html.backup 2>/dev/null || true
echo "✅ 备份完成"
echo ""

echo "📝 修复 task.html..."
cat > templates/task.html << 'ENDOFFILE'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>任务详情 - AutoGLM</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/vue@3/dist/vue.global.js"></script>
</head>
<body class="bg-gray-50">
    <div id="app">
        <nav class="bg-white shadow-sm">
            <div class="max-w-6xl mx-auto px-4 py-4">
                <div class="flex items-center justify-between">
                    <div class="flex items-center gap-4">
                        <a href="/" class="text-blue-600 hover:text-blue-800">← 返回</a>
                        <h1 class="text-xl font-bold text-gray-900">任务详情</h1>
                    </div>
                    <span :class="getStatusBadge(task.status)" v-text="getStatusText(task.status)"></span>
                </div>
            </div>
        </nav>

        <main class="max-w-6xl mx-auto px-4 py-8">
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <div class="bg-white rounded-lg shadow-md p-6">
                    <div class="flex items-center justify-between mb-4">
                        <h2 class="text-lg font-semibold text-gray-900">📋 执行日志</h2>
                        <div v-if="connected" class="flex items-center text-green-600 text-sm">
                            <span class="inline-block w-2 h-2 bg-green-600 rounded-full mr-2 animate-pulse"></span>
                            实时连接中
                        </div>
                    </div>

                    <div class="mb-4 p-3 bg-blue-50 rounded-lg">
                        <p class="text-sm text-gray-700 font-medium">任务描述：</p>
                        <p class="text-sm text-gray-900" v-text="task.description"></p>
                    </div>

                    <div ref="logContainer"
                        class="bg-gray-900 text-green-400 rounded-lg p-4 font-mono text-sm h-96 overflow-y-auto">
                        <div v-if="logs.length === 0" class="text-gray-500">等待日志输出...</div>
                        <div v-for="(log, index) in logs" :key="index" class="mb-1" v-text="log"></div>
                    </div>

                    <div class="mt-4 grid grid-cols-2 gap-4 text-sm">
                        <div>
                            <span class="text-gray-500">任务 ID：</span>
                            <span class="text-gray-900 font-mono" v-text="task.id.substring(0, 8)"></span>
                        </div>
                        <div>
                            <span class="text-gray-500">创建时间：</span>
                            <span class="text-gray-900" v-text="formatFullTime(task.created_at)"></span>
                        </div>
                        <div v-if="task.started_at">
                            <span class="text-gray-500">开始时间：</span>
                            <span class="text-gray-900" v-text="formatFullTime(task.started_at)"></span>
                        </div>
                        <div v-if="task.completed_at">
                            <span class="text-gray-500">完成时间：</span>
                            <span class="text-gray-900" v-text="formatFullTime(task.completed_at)"></span>
                        </div>
                    </div>

                    <div v-if="task.error" class="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg">
                        <p class="text-sm font-medium text-red-700">错误信息：</p>
                        <p class="text-sm text-red-600 mt-1" v-text="task.error"></p>
                    </div>
                </div>

                <div class="bg-white rounded-lg shadow-md p-6">
                    <h2 class="text-lg font-semibold text-gray-900 mb-4">📱 实时截图</h2>

                    <div v-if="task.screenshot" class="border border-gray-200 rounded-lg overflow-hidden">
                        <img :src="task.screenshot" alt="手机截图" class="w-full h-auto" />
                        <div class="p-2 bg-gray-50 text-xs text-gray-500 text-center">
                            <span v-text="'最后更新: ' + new Date().toLocaleTimeString('zh-CN')"></span>
                        </div>
                    </div>

                    <div v-else class="border-2 border-dashed border-gray-300 rounded-lg p-12 text-center">
                        <svg class="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor"
                            viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                                d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z">
                            </path>
                        </svg>
                        <p class="text-gray-500">暂无截图</p>
                        <p class="text-sm text-gray-400 mt-2">任务执行时会自动捕获手机屏幕</p>
                    </div>

                    <div class="mt-4 flex gap-2">
                        <button v-if="task.status === 'running'" @click="refreshTask"
                            class="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition text-sm">
                            🔄 刷新状态
                        </button>
                        <button v-if="task.status === 'completed' || task.status === 'failed'" @click="goBack"
                            class="flex-1 px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition text-sm">
                            ← 返回首页
                        </button>
                    </div>
                </div>
            </div>
        </main>
    </div>

    <script>
        const { createApp } = Vue;
        const taskData = {{ task.to_dict() | tojson }};
        const logsData = {{ task.logs | tojson }};
        const serverToken = '{{ auth_token }}';

        createApp({
            data() {
                return {
                    task: taskData,
                    logs: logsData,
                    authToken: serverToken,
                    connected: false,
                    eventSource: null,
                }
            },
            mounted() {
                const savedToken = localStorage.getItem('authToken');
                if (savedToken) {
                    this.authToken = savedToken;
                }
                if (this.task.status === 'pending' || this.task.status === 'running') {
                    this.connectEventSource();
                }
                this.$nextTick(() => {
                    this.scrollToBottom();
                });
            },
            beforeUnmount() {
                if (this.eventSource) {
                    this.eventSource.close();
                }
            },
            methods: {
                connectEventSource() {
                    const url = `/api/tasks/${this.task.id}/logs`;
                    this.eventSource = new EventSource(url);
                    this.eventSource.onopen = () => {
                        console.log('SSE 连接已建立');
                        this.connected = true;
                    };
                    this.eventSource.onmessage = (event) => {
                        try {
                            const data = JSON.parse(event.data);
                            this.handleSSEMessage(data);
                        } catch (err) {
                            console.error('解析 SSE 消息失败:', err);
                        }
                    };
                    this.eventSource.onerror = (err) => {
                        console.error('SSE 连接错误:', err);
                        this.connected = false;
                        if (this.task.status === 'completed' || this.task.status === 'failed') {
                            this.eventSource.close();
                        }
                    };
                },
                handleSSEMessage(data) {
                    switch (data.type) {
                        case 'init':
                            this.task = data.task;
                            this.logs = data.task.logs;
                            break;
                        case 'log':
                            this.logs.push(data.message);
                            this.$nextTick(() => {
                                this.scrollToBottom();
                            });
                            break;
                        case 'screenshot':
                            this.task.screenshot = data.data;
                            break;
                        case 'status':
                            this.task.status = data.status;
                            break;
                        case 'end':
                            this.task.status = data.status;
                            this.connected = false;
                            if (this.eventSource) {
                                this.eventSource.close();
                            }
                            break;
                    }
                },
                async refreshTask() {
                    try {
                        const response = await fetch(`/api/tasks/${this.task.id}`, {
                            headers: {
                                'Authorization': `Bearer ${this.authToken}`
                            }
                        });
                        if (response.ok) {
                            this.task = await response.json();
                            this.logs = this.task.logs;
                            this.$nextTick(() => {
                                this.scrollToBottom();
                            });
                        }
                    } catch (err) {
                        console.error('刷新任务失败:', err);
                    }
                },
                scrollToBottom() {
                    const container = this.$refs.logContainer;
                    if (container) {
                        container.scrollTop = container.scrollHeight;
                    }
                },
                goBack() {
                    window.location.href = '/';
                },
                getStatusBadge(status) {
                    const badges = {
                        'pending': 'px-3 py-1 text-sm rounded-full bg-gray-100 text-gray-700',
                        'running': 'px-3 py-1 text-sm rounded-full bg-blue-100 text-blue-700',
                        'completed': 'px-3 py-1 text-sm rounded-full bg-green-100 text-green-700',
                        'failed': 'px-3 py-1 text-sm rounded-full bg-red-100 text-red-700'
                    };
                    return badges[status] || badges['pending'];
                },
                getStatusText(status) {
                    const texts = {
                        'pending': '⏳ 等待中',
                        'running': '⚙️ 执行中',
                        'completed': '✅ 已完成',
                        'failed': '❌ 失败'
                    };
                    return texts[status] || status;
                },
                formatFullTime(isoString) {
                    if (!isoString) return '-';
                    const date = new Date(isoString);
                    return date.toLocaleString('zh-CN');
                }
            }
        }).mount('#app');
    </script>
</body>
</html>
ENDOFFILE

echo "✅ task.html 已修复"
echo ""

echo "📝 修复 history.html..."
cat > templates/history.html << 'ENDOFFILE'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>历史记录 - AutoGLM</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/vue@3/dist/vue.global.js"></script>
</head>
<body class="bg-gray-50">
    <div id="app">
        <nav class="bg-white shadow-sm">
            <div class="max-w-6xl mx-auto px-4 py-4">
                <div class="flex items-center justify-between">
                    <div class="flex items-center gap-4">
                        <a href="/" class="text-blue-600 hover:text-blue-800">← 返回首页</a>
                        <h1 class="text-xl font-bold text-gray-900">📜 历史记录</h1>
                    </div>
                    <button @click="loadTasks"
                        class="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition">
                        🔄 刷新
                    </button>
                </div>
            </div>
        </nav>

        <main class="max-w-6xl mx-auto px-4 py-8">
            <div class="bg-white rounded-lg shadow-md p-4 mb-6">
                <div class="flex items-center gap-4">
                    <label class="text-sm text-gray-700">状态筛选：</label>
                    <button v-for="status in statusOptions" :key="status.value" @click="filterStatus = status.value"
                        :class="[
                            'px-3 py-1 text-sm rounded-full transition',
                            filterStatus === status.value ? status.activeClass : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                        ]" v-text="status.label">
                    </button>
                </div>
            </div>

            <div v-if="loading" class="text-center py-12">
                <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-600 mx-auto mb-4"></div>
                <p class="text-gray-500">加载中...</p>
            </div>

            <div v-else-if="filteredTasks.length > 0" class="space-y-4">
                <div v-for="task in filteredTasks" :key="task.id"
                    class="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition cursor-pointer"
                    @click="goToTask(task.id)">
                    <div class="flex items-start justify-between mb-3">
                        <div class="flex-1">
                            <div class="flex items-center gap-3 mb-2">
                                <span :class="getStatusBadge(task.status)" v-text="getStatusText(task.status)"></span>
                                <span class="text-sm text-gray-500" v-text="formatTime(task.created_at)"></span>
                            </div>
                            <h3 class="text-lg font-medium text-gray-900 mb-2" v-text="task.description"></h3>
                        </div>
                        <svg class="w-6 h-6 text-gray-400 flex-shrink-0 ml-4" fill="none" stroke="currentColor"
                            viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7">
                            </path>
                        </svg>
                    </div>

                    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                        <div>
                            <span class="text-gray-500">任务 ID</span>
                            <p class="text-gray-900 font-mono" v-text="task.id.substring(0, 8) + '...'"></p>
                        </div>
                        <div v-if="task.started_at">
                            <span class="text-gray-500">开始时间</span>
                            <p class="text-gray-900" v-text="formatFullTime(task.started_at)"></p>
                        </div>
                        <div v-if="task.completed_at">
                            <span class="text-gray-500">完成时间</span>
                            <p class="text-gray-900" v-text="formatFullTime(task.completed_at)"></p>
                        </div>
                        <div v-if="task.completed_at && task.started_at">
                            <span class="text-gray-500">耗时</span>
                            <p class="text-gray-900" v-text="getDuration(task.started_at, task.completed_at)"></p>
                        </div>
                    </div>

                    <div v-if="task.logs && task.logs.length > 0" class="mt-4 p-3 bg-gray-50 rounded-lg">
                        <p class="text-xs text-gray-500 mb-1">最新日志：</p>
                        <p class="text-sm text-gray-700 font-mono" v-text="task.logs[task.logs.length - 1]"></p>
                    </div>

                    <div v-if="task.error" class="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg">
                        <p class="text-sm text-red-700">
                            <span class="font-medium">错误：</span><span v-text="task.error"></span>
                        </p>
                    </div>
                </div>
            </div>

            <div v-else class="bg-white rounded-lg shadow-md p-12 text-center">
                <svg class="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor"
                    viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                        d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z">
                    </path>
                </svg>
                <p class="text-gray-500 text-lg">暂无任务记录</p>
                <a href="/"
                    class="mt-4 inline-block px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition">
                    去提交任务
                </a>
            </div>
        </main>
    </div>

    <script>
        const { createApp } = Vue;

        createApp({
            data() {
                return {
                    tasks: [],
                    loading: false,
                    filterStatus: 'all',
                    authToken: '',
                    statusOptions: [
                        { value: 'all', label: '全部', activeClass: 'bg-blue-600 text-white' },
                        { value: 'pending', label: '等待中', activeClass: 'bg-gray-600 text-white' },
                        { value: 'running', label: '执行中', activeClass: 'bg-blue-600 text-white' },
                        { value: 'completed', label: '已完成', activeClass: 'bg-green-600 text-white' },
                        { value: 'failed', label: '失败', activeClass: 'bg-red-600 text-white' },
                    ]
                }
            },
            computed: {
                filteredTasks() {
                    if (this.filterStatus === 'all') {
                        return this.tasks;
                    }
                    return this.tasks.filter(task => task.status === this.filterStatus);
                }
            },
            mounted() {
                const savedToken = localStorage.getItem('authToken');
                if (savedToken) {
                    this.authToken = savedToken;
                    this.loadTasks();
                } else {
                    alert('请先在首页配置 Token');
                    window.location.href = '/';
                }
            },
            methods: {
                async loadTasks() {
                    this.loading = true;
                    try {
                        const response = await fetch('/api/tasks?limit=50', {
                            headers: {
                                'Authorization': `Bearer ${this.authToken}`
                            }
                        });
                        if (response.ok) {
                            this.tasks = await response.json();
                        } else {
                            console.error('加载任务列表失败');
                            alert('加载失败，请检查 Token 是否正确');
                        }
                    } catch (err) {
                        console.error('加载任务列表失败:', err);
                        alert('网络错误');
                    } finally {
                        this.loading = false;
                    }
                },
                goToTask(taskId) {
                    window.location.href = `/task/${taskId}`;
                },
                getStatusBadge(status) {
                    const badges = {
                        'pending': 'px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-700',
                        'running': 'px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-700',
                        'completed': 'px-2 py-1 text-xs rounded-full bg-green-100 text-green-700',
                        'failed': 'px-2 py-1 text-xs rounded-full bg-red-100 text-red-700'
                    };
                    return badges[status] || badges['pending'];
                },
                getStatusText(status) {
                    const texts = {
                        'pending': '⏳ 等待中',
                        'running': '⚙️ 执行中',
                        'completed': '✅ 已完成',
                        'failed': '❌ 失败'
                    };
                    return texts[status] || status;
                },
                formatTime(isoString) {
                    const date = new Date(isoString);
                    const now = new Date();
                    const diffMs = now - date;
                    const diffMins = Math.floor(diffMs / 60000);
                    if (diffMins < 1) return '刚刚';
                    if (diffMins < 60) return `${diffMins} 分钟前`;
                    if (diffMins < 1440) return `${Math.floor(diffMins / 60)} 小时前`;
                    return date.toLocaleDateString('zh-CN');
                },
                formatFullTime(isoString) {
                    if (!isoString) return '-';
                    const date = new Date(isoString);
                    return date.toLocaleTimeString('zh-CN');
                },
                getDuration(startTime, endTime) {
                    const start = new Date(startTime);
                    const end = new Date(endTime);
                    const diffMs = end - start;
                    const diffSecs = Math.floor(diffMs / 1000);
                    if (diffSecs < 60) return `${diffSecs} 秒`;
                    const diffMins = Math.floor(diffSecs / 60);
                    return `${diffMins} 分 ${diffSecs % 60} 秒`;
                }
            }
        }).mount('#app');
    </script>
</body>
</html>
ENDOFFILE

echo "✅ history.html 已修复"
echo ""

echo "======================================"
echo "✅ 所有模板已修复完成！"
echo "======================================"
echo ""
echo "现在重新启动服务："
echo "  按 Ctrl+C 停止当前服务"
echo "  然后运行: ./setup-and-start.sh"
echo ""
