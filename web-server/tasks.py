"""
任务管理器（AI 增强版）
集成 Open-AutoGLM 的完整 AI 逻辑
"""

import json
import logging
import threading
import time
import uuid
import base64
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
from queue import Queue
from io import BytesIO

# 添加路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'mac-server'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'Open-AutoGLM'))

from config import TASK_HISTORY_FILE, MAX_TASK_HISTORY, PHONE_HELPER_URL
from phone_controller_remote import PhoneControllerRemote
from phone_adapter import PhoneControllerAdapter

# 导入 PhoneAgent 相关模块
try:
    from phone_agent import PhoneAgent
    from phone_agent.model import ModelConfig
    from phone_agent.agent import AgentConfig
    from phone_agent.device_factory import get_device_factory, set_device_type, DeviceType
    AI_AVAILABLE = True
except ImportError as e:
    logger_temp = logging.getLogger(__name__)
    logger_temp.warning(f"无法导入 PhoneAgent: {e}")
    AI_AVAILABLE = False

logger = logging.getLogger(__name__)


class TaskStatus:
    """任务状态枚举"""
    PENDING = 'pending'      # 等待执行
    RUNNING = 'running'      # 执行中
    COMPLETED = 'completed'  # 已完成
    FAILED = 'failed'        # 失败


class Task:
    """任务对象"""

    def __init__(self, description: str, task_id: str = None):
        self.id = task_id or str(uuid.uuid4())
        self.description = description
        self.status = TaskStatus.PENDING
        self.created_at = datetime.now().isoformat()
        self.started_at: Optional[str] = None
        self.completed_at: Optional[str] = None
        self.logs: List[str] = []
        self.screenshots: List[str] = []  # 支持多张截图
        self.thinking: Optional[str] = None  # AI 思考过程
        self.actions: List[dict] = []  # AI 执行的动作列表
        self.error: Optional[str] = None

    @property
    def screenshot(self) -> Optional[str]:
        """兼容旧版本，返回最后一张截图"""
        return self.screenshots[-1] if self.screenshots else None

    @screenshot.setter
    def screenshot(self, value: str):
        """兼容旧版本，添加截图"""
        if value:
            self.screenshots.append(value)

    def to_dict(self) -> dict:
        """转换为字典"""
        return {
            'id': self.id,
            'description': self.description,
            'status': self.status,
            'created_at': self.created_at,
            'started_at': self.started_at,
            'completed_at': self.completed_at,
            'logs': self.logs,
            'screenshot': self.screenshot,  # 兼容旧版本
            'screenshots': self.screenshots,
            'thinking': self.thinking,
            'actions': self.actions,
            'error': self.error,
        }

    @classmethod
    def from_dict(cls, data: dict) -> 'Task':
        """从字典创建任务"""
        task = cls(data['description'], data['id'])
        task.status = data['status']
        task.created_at = data['created_at']
        task.started_at = data.get('started_at')
        task.completed_at = data.get('completed_at')
        task.logs = data.get('logs', [])
        task.screenshots = data.get('screenshots', [])
        task.thinking = data.get('thinking')
        task.actions = data.get('actions', [])
        task.error = data.get('error')
        return task

    def add_log(self, message: str):
        """添加日志"""
        timestamp = datetime.now().strftime('%H:%M:%S')
        log_entry = f"[{timestamp}] {message}"
        self.logs.append(log_entry)
        logger.info(f"任务 {self.id[:8]}: {message}")


class TaskManager:
    """
    任务管理器（单例，AI 增强版）
    集成 Open-AutoGLM 的完整 AI 规划能力
    """

    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if hasattr(self, '_initialized'):
            return

        self._initialized = True
        self.current_task: Optional[Task] = None
        self.task_queue = Queue()
        self.task_history: Dict[str, Task] = {}
        self.worker_thread: Optional[threading.Thread] = None
        self.running = False
        self.phone_agent: Optional['PhoneAgent'] = None

        # 初始化手机控制器
        try:
            self.phone_controller = PhoneControllerRemote(helper_url=PHONE_HELPER_URL)
            logger.info("✅ 手机控制器初始化成功")
        except Exception as e:
            logger.error(f"❌ 手机控制器初始化失败: {e}")
            self.phone_controller = None

        # 初始化 AI Agent（如果可用）
        if AI_AVAILABLE and self.phone_controller:
            try:
                self._init_phone_agent()
            except Exception as e:
                logger.error(f"❌ PhoneAgent 初始化失败: {e}", exc_info=True)
                self.phone_agent = None
        else:
            logger.warning("⚠️ AI 功能不可用，将使用简单模式")

        # 加载历史记录
        self._load_history()

    def _init_phone_agent(self):
        """初始化 PhoneAgent"""
        # 创建适配器
        adapter = PhoneControllerAdapter(self.phone_controller)

        # 创建自定义 device_factory
        class CustomDeviceFactory:
            def __init__(self, adapter):
                self.adapter = adapter

            def get_screenshot(self, device_id=None, timeout=10):
                return self.adapter.get_screenshot(device_id, timeout)

            def get_current_app(self, device_id=None):
                return self.adapter.get_current_app(device_id)

            def tap(self, x, y, device_id=None, delay=None):
                return self.adapter.tap(x, y, device_id, delay)

            def swipe(self, start_x, start_y, end_x, end_y, duration_ms=None, device_id=None, delay=None):
                return self.adapter.swipe(start_x, start_y, end_x, end_y, duration_ms, device_id, delay)

            def type_text(self, text, device_id=None):
                return self.adapter.type_text(text, device_id)

            def long_press(self, x, y, duration_ms=3000, device_id=None, delay=None):
                return self.adapter.long_press(x, y, duration_ms, device_id, delay)

            def back(self, device_id=None, delay=None):
                return self.adapter.back(device_id, delay)

            def home(self, device_id=None, delay=None):
                return self.adapter.home(device_id, delay)

        # 替换全局 device_factory
        import phone_agent.device_factory as factory_module
        factory_module._device_factory = CustomDeviceFactory(adapter)

        # 读取配置
        api_key = os.getenv('PHONE_AGENT_API_KEY', 'EMPTY')
        base_url = os.getenv('PHONE_AGENT_BASE_URL', 'https://api.grsai.com/v1')
        model_name = os.getenv('PHONE_AGENT_MODEL', 'gpt-4-vision-preview')

        # 创建 ModelConfig
        model_config = ModelConfig(
            base_url=base_url,
            api_key=api_key,
            model_name=model_name,
            lang='cn'
        )

        # 创建 AgentConfig
        agent_config = AgentConfig(
            max_steps=20,  # 最多 20 步
            lang='cn',
            verbose=True
        )

        # 创建 PhoneAgent
        self.phone_agent = PhoneAgent(
            model_config=model_config,
            agent_config=agent_config
        )

        logger.info("✅ PhoneAgent 初始化成功")
        logger.info(f"   - API Base URL: {base_url}")
        logger.info(f"   - Model: {model_name}")

    def submit_task(self, description: str) -> Task:
        """提交新任务"""
        task = Task(description)
        task.add_log("任务已提交到队列")

        # 添加到队列
        self.task_queue.put(task)

        # 添加到历史
        self.task_history[task.id] = task

        # 启动 worker（如果未启动）
        if not self.running:
            self.start_worker()

        logger.info(f"任务已提交: {task.id}, 描述: {description}")
        return task

    def get_task(self, task_id: str) -> Optional[Task]:
        """获取任务"""
        return self.task_history.get(task_id)

    def get_current_task(self) -> Optional[Task]:
        """获取当前正在执行的任务"""
        return self.current_task

    def get_recent_tasks(self, limit: int = 20) -> List[Task]:
        """获取最近的任务列表"""
        tasks = sorted(
            self.task_history.values(),
            key=lambda t: t.created_at,
            reverse=True
        )
        return tasks[:limit]

    def start_worker(self):
        """启动任务执行线程"""
        if self.running:
            logger.warning("Worker 已在运行")
            return

        self.running = True
        self.worker_thread = threading.Thread(target=self._worker_loop, daemon=True)
        self.worker_thread.start()
        logger.info("任务 worker 已启动")

    def stop_worker(self):
        """停止任务执行线程"""
        self.running = False
        if self.worker_thread:
            self.worker_thread.join(timeout=5)
        logger.info("任务 worker 已停止")

    def _worker_loop(self):
        """Worker 主循环"""
        logger.info("Worker 循环已启动")

        while self.running:
            try:
                # 从队列获取任务
                if not self.task_queue.empty():
                    task = self.task_queue.get(timeout=1)
                    self.current_task = task

                    # 执行任务
                    self._execute_task(task)

                    self.current_task = None
                    self.task_queue.task_done()
                else:
                    time.sleep(0.5)

            except Exception as e:
                logger.error(f"Worker 循环错误: {e}", exc_info=True)
                time.sleep(1)

        logger.info("Worker 循环已退出")

    def _execute_task(self, task: Task):
        """执行单个任务"""
        try:
            task.status = TaskStatus.RUNNING
            task.started_at = datetime.now().isoformat()
            task.add_log("开始执行任务...")

            # 检查手机控制器是否可用
            if not self.phone_controller:
                raise Exception("手机控制器未初始化")

            # 使用 AI Agent（如果可用）
            if self.phone_agent:
                self._execute_with_ai(task)
            else:
                self._execute_simple(task)

            # 完成
            task.status = TaskStatus.COMPLETED
            task.completed_at = datetime.now().isoformat()
            task.add_log("✅ 任务执行完成")

        except Exception as e:
            task.status = TaskStatus.FAILED
            task.completed_at = datetime.now().isoformat()
            task.error = str(e)
            task.add_log(f"❌ 任务执行失败: {e}")
            logger.error(f"任务 {task.id} 执行失败: {e}", exc_info=True)

        finally:
            # 保存历史
            self._save_history()

    def _execute_with_ai(self, task: Task):
        """
        使用 PhoneAgent 执行任务（完整 AI 逻辑）
        """
        task.add_log("🤖 使用 AI 规划模式")
        task.add_log("正在分析任务...")

        # 重置 agent 状态
        self.phone_agent.reset()

        # 执行任务，逐步执行
        step_count = 0
        max_steps = 20

        while step_count < max_steps:
            try:
                # 执行一步
                task.add_log(f"执行第 {step_count + 1} 步...")

                # 第一步传入任务描述
                if step_count == 0:
                    result = self.phone_agent.step(task.description)
                else:
                    result = self.phone_agent.step()

                step_count += 1

                # 记录思考过程
                if result.thinking:
                    task.thinking = result.thinking
                    task.add_log(f"💭 AI 思考: {result.thinking[:100]}...")

                # 记录动作
                if result.action:
                    task.actions.append(result.action)
                    action_type = result.action.get('_metadata', 'unknown')
                    task.add_log(f"🎯 执行动作: {action_type}")

                # 获取截图
                try:
                    screenshot = self.phone_agent._context[-2] if len(self.phone_agent._context) >= 2 else None
                    if screenshot and 'content' in screenshot:
                        for content in screenshot['content']:
                            if isinstance(content, dict) and content.get('type') == 'image_url':
                                # 提取 base64 图片
                                image_url = content.get('image_url', {}).get('url', '')
                                if image_url.startswith('data:image'):
                                    task.screenshots.append(image_url)
                                    task.add_log("📸 已保存截图")
                                    break
                except Exception as e:
                    logger.debug(f"提取截图失败: {e}")

                # 检查是否完成
                if result.finished:
                    task.add_log(f"✅ 任务完成: {result.message or '操作成功'}")
                    break

                # 短暂延迟
                time.sleep(0.5)

            except Exception as e:
                task.add_log(f"⚠️ 步骤执行错误: {e}")
                logger.error(f"步骤 {step_count} 执行错误: {e}", exc_info=True)
                break

        if step_count >= max_steps:
            task.add_log("⚠️ 达到最大步数限制")

    def _execute_simple(self, task: Task):
        """
        简单模式执行（无 AI，仅支持基础命令）
        """
        task.add_log("⚠️ 使用简单模式（无 AI 规划）")
        description = task.description.strip()

        # 解析简单命令
        if description == "截图" or description.startswith("screenshot"):
            task.add_log("正在截取屏幕...")
            self._do_screenshot(task)

        elif description.startswith("点击"):
            parts = description.replace(",", " ").split()
            if len(parts) >= 3:
                x, y = int(parts[1]), int(parts[2])
                task.add_log(f"正在点击 ({x}, {y})...")
                self._do_tap(task, x, y)
            else:
                raise Exception("点击命令格式错误，应为: 点击 x,y")

        elif description.startswith("滑动"):
            parts = description.replace(",", " ").split()
            if len(parts) >= 5:
                x1, y1, x2, y2 = int(parts[1]), int(parts[2]), int(parts[3]), int(parts[4])
                task.add_log(f"正在滑动 ({x1},{y1}) -> ({x2},{y2})...")
                self._do_swipe(task, x1, y1, x2, y2)
            else:
                raise Exception("滑动命令格式错误，应为: 滑动 x1,y1,x2,y2")

        elif description.startswith("输入"):
            text = description[2:].strip()
            if text:
                task.add_log(f"正在输入: {text}")
                self._do_input(task, text)
            else:
                raise Exception("输入命令格式错误，应为: 输入 文本")

        else:
            raise Exception(f"无 AI 模式下不支持自然语言任务，请使用简单命令（截图/点击/滑动/输入）")

    def _do_screenshot(self, task: Task):
        """截取屏幕并保存"""
        try:
            image = self.phone_controller.screenshot()
            if image:
                buffer = BytesIO()
                image.save(buffer, format='PNG')
                img_data = base64.b64encode(buffer.getvalue()).decode()
                task.screenshots.append(f"data:image/png;base64,{img_data}")
                task.add_log(f"✅ 截图成功 ({image.size[0]}x{image.size[1]})")
            else:
                task.add_log("⚠️ 截图失败")
        except Exception as e:
            task.add_log(f"⚠️ 截图错误: {e}")

    def _do_tap(self, task: Task, x: int, y: int):
        """执行点击"""
        try:
            success = self.phone_controller.tap(x, y)
            if success:
                task.add_log(f"✅ 点击成功 ({x}, {y})")
            else:
                task.add_log(f"⚠️ 点击失败")
        except Exception as e:
            task.add_log(f"⚠️ 点击错误: {e}")

    def _do_swipe(self, task: Task, x1: int, y1: int, x2: int, y2: int, duration: int = 300):
        """执行滑动"""
        try:
            success = self.phone_controller.swipe(x1, y1, x2, y2, duration)
            if success:
                task.add_log(f"✅ 滑动成功")
            else:
                task.add_log(f"⚠️ 滑动失败")
        except Exception as e:
            task.add_log(f"⚠️ 滑动错误: {e}")

    def _do_input(self, task: Task, text: str):
        """输入文字"""
        try:
            success = self.phone_controller.input_text(text)
            if success:
                task.add_log(f"✅ 输入成功")
            else:
                task.add_log(f"⚠️ 输入失败")
        except Exception as e:
            task.add_log(f"⚠️ 输入错误: {e}")

    def _load_history(self):
        """从文件加载任务历史"""
        if not TASK_HISTORY_FILE.exists():
            logger.info("任务历史文件不存在，创建新文件")
            return

        try:
            with open(TASK_HISTORY_FILE, 'r', encoding='utf-8') as f:
                data = json.load(f)
                for task_dict in data:
                    task = Task.from_dict(task_dict)
                    self.task_history[task.id] = task
            logger.info(f"已加载 {len(self.task_history)} 条任务历史")
        except Exception as e:
            logger.error(f"加载任务历史失败: {e}", exc_info=True)

    def _save_history(self):
        """保存任务历史到文件"""
        try:
            recent_tasks = self.get_recent_tasks(MAX_TASK_HISTORY)
            data = [task.to_dict() for task in recent_tasks]

            TASK_HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)

            with open(TASK_HISTORY_FILE, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)

            logger.debug(f"任务历史已保存: {len(data)} 条记录")
        except Exception as e:
            logger.error(f"保存任务历史失败: {e}", exc_info=True)


# 全局单例
task_manager = TaskManager()
