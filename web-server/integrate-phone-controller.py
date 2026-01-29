#!/usr/bin/env python3
"""
集成真实的手机控制器到 tasks.py
"""

import sys
import re

def integrate():
    """修改 tasks.py，集成真实的手机控制器"""

    tasks_file = 'tasks.py'

    # 读取文件
    with open(tasks_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 备份
    with open(tasks_file + '.backup', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ 已备份 tasks.py -> tasks.py.backup")

    # 1. 在文件开头添加导入
    import_section = """import json
import logging
import threading
import time
import uuid
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
from queue import Queue

from config import TASK_HISTORY_FILE, MAX_TASK_HISTORY"""

    new_import = """import json
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

# 添加 mac-server 目录到路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'mac-server'))

from config import TASK_HISTORY_FILE, MAX_TASK_HISTORY
from phone_controller_remote import PhoneControllerRemote"""

    content = content.replace(import_section, new_import)
    print("✅ 已添加手机控制器导入")

    # 2. 在 TaskManager.__init__ 中添加控制器初始化
    init_pattern = r"(self\.running = False\s+# 加载历史记录)"
    init_replacement = r"""self.running = False

        # 初始化手机控制器
        try:
            self.phone_controller = PhoneControllerRemote()
            logger.info("✅ 手机控制器初始化成功")
        except Exception as e:
            logger.error(f"❌ 手机控制器初始化失败: {e}")
            self.phone_controller = None

        # 加载历史记录"""

    content = re.sub(init_pattern, init_replacement, content)
    print("✅ 已添加控制器初始化代码")

    # 3. 替换 _execute_task 方法
    execute_method = '''    def _execute_task(self, task: Task):
        """
        执行单个任务
        """
        try:
            task.status = TaskStatus.RUNNING
            task.started_at = datetime.now().isoformat()
            task.add_log("开始执行任务...")

            # 检查手机控制器是否可用
            if not self.phone_controller:
                raise Exception("手机控制器未初始化")

            # 执行真实的任务
            self._execute_real_task(task)

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
            self._save_history()'''

    # 找到并替换 _execute_task 方法
    pattern = r'    def _execute_task\(self, task: Task\):.*?finally:\s+# 保存历史\s+self\._save_history\(\)'
    content = re.sub(pattern, execute_method, content, flags=re.DOTALL)
    print("✅ 已更新任务执行方法")

    # 4. 添加真实任务执行方法（替换 _simulate_task_execution）
    real_execute = '''    def _execute_real_task(self, task: Task):
        """
        执行真实任务
        支持的命令格式：
        - "截图" - 截取手机屏幕
        - "点击 x,y" - 点击指定坐标
        - "滑动 x1,y1,x2,y2" - 滑动手势
        - "输入 文本" - 输入文字
        - 其他文本 - 简单测试（截图+点击中心）
        """
        description = task.description.strip()

        # 解析命令
        if description == "截图" or description.startswith("screenshot"):
            task.add_log("正在截取屏幕...")
            self._do_screenshot(task)

        elif description.startswith("点击"):
            # 格式: "点击 100,200" 或 "点击 100 200"
            parts = description.replace(",", " ").split()
            if len(parts) >= 3:
                try:
                    x = int(parts[1])
                    y = int(parts[2])
                    task.add_log(f"正在点击坐标 ({x}, {y})...")
                    self._do_tap(task, x, y)
                except ValueError:
                    raise Exception(f"无效的坐标格式: {description}")
            else:
                raise Exception("点击命令格式错误，应为: 点击 x,y")

        elif description.startswith("滑动"):
            # 格式: "滑动 100,200,300,400"
            parts = description.replace(",", " ").split()
            if len(parts) >= 5:
                try:
                    x1, y1, x2, y2 = int(parts[1]), int(parts[2]), int(parts[3]), int(parts[4])
                    task.add_log(f"正在滑动 ({x1},{y1}) -> ({x2},{y2})...")
                    self._do_swipe(task, x1, y1, x2, y2)
                except ValueError:
                    raise Exception(f"无效的坐标格式: {description}")
            else:
                raise Exception("滑动命令格式错误，应为: 滑动 x1,y1,x2,y2")

        elif description.startswith("输入"):
            # 格式: "输入 你好世界"
            text = description[2:].strip()
            if text:
                task.add_log(f"正在输入文字: {text}")
                self._do_input(task, text)
            else:
                raise Exception("输入命令格式错误，应为: 输入 文本内容")

        else:
            # 默认：演示性任务（截图 + 简单测试）
            task.add_log(f"执行任务: {description}")
            task.add_log("正在截取屏幕...")
            self._do_screenshot(task)
            time.sleep(1)
            task.add_log("测试点击屏幕中心...")
            self._do_tap(task, 540, 1000)  # 大部分手机的中心位置

    def _do_screenshot(self, task: Task):
        """截取屏幕并保存到任务"""
        try:
            image = self.phone_controller.screenshot()
            if image:
                # 转换为 Base64
                from io import BytesIO
                buffer = BytesIO()
                image.save(buffer, format='PNG')
                img_data = base64.b64encode(buffer.getvalue()).decode()
                task.screenshot = f"data:image/png;base64,{img_data}"
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
            task.add_log(f"⚠️ 输入错误: {e}")'''

    # 替换 _simulate_task_execution 方法
    pattern = r'    def _simulate_task_execution\(self, task: Task\):.*?time\.sleep\(1\)'
    content = re.sub(pattern, real_execute, content, flags=re.DOTALL)
    print("✅ 已添加真实任务执行逻辑")

    # 写回文件
    with open(tasks_file, 'w', encoding='utf-8') as f:
        f.write(content)

    print("\n" + "="*50)
    print("✅ 集成完成！")
    print("="*50)
    print("\n支持的命令格式:")
    print("  - '截图' - 截取手机屏幕")
    print("  - '点击 x,y' - 点击指定坐标（如：点击 500,1000）")
    print("  - '滑动 x1,y1,x2,y2' - 滑动手势（如：滑动 500,1500,500,500）")
    print("  - '输入 文本' - 输入文字（如：输入 你好）")
    print("  - 其他任意文本 - 会截图并点击屏幕中心测试\n")

if __name__ == '__main__':
    integrate()
