"""
PhoneController 适配器
将 PhoneControllerRemote（HTTP）适配为 device_factory 接口
"""

import base64
import logging
from io import BytesIO
from dataclasses import dataclass
from typing import Optional
from PIL import Image

from phone_controller_remote import PhoneControllerRemote

logger = logging.getLogger(__name__)


@dataclass
class Screenshot:
    """截图数据"""
    image: Image.Image
    width: int
    height: int
    base64_data: str


class PhoneControllerAdapter:
    """
    将 PhoneControllerRemote 适配为 device_factory 接口

    这样 PhoneAgent 就能通过 HTTP 控制手机，而不需要 ADB
    """

    def __init__(self, phone_controller: PhoneControllerRemote):
        self.controller = phone_controller
        logger.info("PhoneControllerAdapter 初始化完成")

    def get_screenshot(self, device_id: str = None, timeout: int = 10) -> Screenshot:
        """获取屏幕截图"""
        try:
            image = self.controller.screenshot()
            if not image:
                raise Exception("截图失败")

            # 转换为 Base64
            buffer = BytesIO()
            image.save(buffer, format='PNG')
            base64_data = base64.b64encode(buffer.getvalue()).decode()

            return Screenshot(
                image=image,
                width=image.width,
                height=image.height,
                base64_data=base64_data
            )
        except Exception as e:
            logger.error(f"获取截图失败: {e}")
            raise

    def get_current_app(self, device_id: str = None) -> str:
        """获取当前应用名称"""
        # HTTP 接口暂不支持，返回空字符串
        return ""

    def tap(self, x: int, y: int, device_id: str = None, delay: float = None):
        """点击坐标"""
        try:
            success = self.controller.tap(x, y)
            if delay:
                import time
                time.sleep(delay)
            return success
        except Exception as e:
            logger.error(f"点击失败 ({x}, {y}): {e}")
            return False

    def double_tap(self, x: int, y: int, device_id: str = None, delay: float = None):
        """双击坐标"""
        # 通过两次点击模拟双击
        self.tap(x, y, device_id)
        import time
        time.sleep(0.1)
        return self.tap(x, y, device_id, delay)

    def long_press(self, x: int, y: int, duration_ms: int = 3000, device_id: str = None, delay: float = None):
        """长按坐标"""
        # HTTP 接口暂不支持长按，使用普通点击代替
        logger.warning("长按操作暂不支持，使用普通点击代替")
        return self.tap(x, y, device_id, delay)

    def swipe(self, start_x: int, start_y: int, end_x: int, end_y: int,
              duration_ms: int = None, device_id: str = None, delay: float = None):
        """滑动手势"""
        try:
            duration = duration_ms or 300
            success = self.controller.swipe(start_x, start_y, end_x, end_y, duration)
            if delay:
                import time
                time.sleep(delay)
            return success
        except Exception as e:
            logger.error(f"滑动失败: {e}")
            return False

    def back(self, device_id: str = None, delay: float = None):
        """返回键"""
        # HTTP 接口暂不支持系统按键
        logger.warning("返回键操作暂不支持")
        return False

    def home(self, device_id: str = None, delay: float = None):
        """Home键"""
        # HTTP 接口暂不支持系统按键
        logger.warning("Home键操作暂不支持")
        return False

    def launch_app(self, app_name: str, device_id: str = None, delay: float = None) -> bool:
        """启动应用"""
        # HTTP 接口暂不支持直接启动应用
        logger.warning(f"启动应用操作暂不支持: {app_name}")
        return False

    def type_text(self, text: str, device_id: str = None):
        """输入文字"""
        try:
            return self.controller.input_text(text)
        except Exception as e:
            logger.error(f"输入文字失败: {e}")
            return False

    def clear_text(self, device_id: str = None):
        """清除文字"""
        # HTTP 接口暂不支持清除文字
        logger.warning("清除文字操作暂不支持")
        return False

    def detect_and_set_adb_keyboard(self, device_id: str = None) -> str:
        """检测并设置ADB键盘"""
        # HTTP 接口不需要设置键盘
        return ""

    def restore_keyboard(self, ime: str, device_id: str = None):
        """恢复键盘"""
        # HTTP 接口不需要恢复键盘
        pass

    def list_devices(self):
        """列出设备"""
        # HTTP 接口只有一个设备
        return ["remote-phone"]

    def get_connection_class(self):
        """获取连接类"""
        return None
