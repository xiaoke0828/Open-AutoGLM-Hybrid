"""
Open-AutoGLM Mac 服务器 - 远程手机控制器
版本: 1.0.0

通过网络连接到手机的 AutoGLM Helper 进行远程控制
支持局域网和 Tailscale 远程连接
"""

import os
import requests
import base64
import logging
from typing import Optional
from PIL import Image
from io import BytesIO

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('PhoneControllerRemote')


class PhoneControllerRemote:
    """远程手机控制器 - Mac 服务器版本"""

    def __init__(self, helper_url: Optional[str] = None):
        """
        初始化远程手机控制器

        Args:
            helper_url: AutoGLM Helper 的 URL，如果不指定则从环境变量读取
        """
        # 从环境变量或参数获取 URL
        self.helper_url = helper_url or os.getenv('PHONE_HELPER_URL', 'http://localhost:8080')

        logger.info(f"初始化远程手机控制器: {self.helper_url}")

        # 测试连接
        if not self._test_connection():
            raise Exception(
                f"无法连接到手机控制服务: {self.helper_url}\n"
                "请确保:\n"
                "1. 手机上的 AutoGLM Helper 已运行并开启无障碍权限\n"
                "2. 手机和 Mac 在同一网络或已配置 Tailscale\n"
                "3. config.env 中的 PHONE_HELPER_URL 配置正确\n"
            )

    def _test_connection(self) -> bool:
        """测试与手机的连接"""
        try:
            response = requests.get(
                f"{self.helper_url}/status",
                timeout=5
            )

            if response.status_code == 200:
                data = response.json()
                if data.get('accessibility_enabled'):
                    logger.info("✅ 成功连接到手机，无障碍服务已启用")
                    return True
                else:
                    logger.warning("⚠️ 已连接到手机，但无障碍服务未启用")
                    return False

            logger.error(f"连接失败: HTTP {response.status_code}")
            return False

        except requests.exceptions.ConnectionError:
            logger.error(f"连接失败: 无法访问 {self.helper_url}")
            return False
        except Exception as e:
            logger.error(f"连接失败: {e}")
            return False

    def screenshot(self) -> Optional[Image.Image]:
        """
        截取手机屏幕

        Returns:
            PIL.Image 对象，失败返回 None
        """
        try:
            response = requests.get(
                f"{self.helper_url}/screenshot",
                timeout=15
            )

            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    # 解码 Base64 图片
                    image_data = base64.b64decode(data['image'])
                    image = Image.open(BytesIO(image_data))
                    logger.debug(f"截图成功: {image.size}")
                    return image

            logger.error(f"截图失败: HTTP {response.status_code}")
            return None

        except Exception as e:
            logger.error(f"截图失败: {e}")
            return None

    def tap(self, x: int, y: int) -> bool:
        """
        执行点击操作

        Args:
            x: X 坐标
            y: Y 坐标

        Returns:
            是否成功
        """
        try:
            response = requests.post(
                f"{self.helper_url}/tap",
                json={'x': x, 'y': y},
                timeout=5
            )

            if response.status_code == 200:
                data = response.json()
                success = data.get('success', False)
                logger.debug(f"点击 ({x}, {y}): {success}")
                return success

            return False

        except Exception as e:
            logger.error(f"点击失败: {e}")
            return False

    def swipe(self, x1: int, y1: int, x2: int, y2: int, duration: int = 300) -> bool:
        """
        执行滑动操作

        Args:
            x1: 起点 X 坐标
            y1: 起点 Y 坐标
            x2: 终点 X 坐标
            y2: 终点 Y 坐标
            duration: 持续时间 (毫秒)

        Returns:
            是否成功
        """
        try:
            response = requests.post(
                f"{self.helper_url}/swipe",
                json={'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2, 'duration': duration},
                timeout=10
            )

            if response.status_code == 200:
                data = response.json()
                success = data.get('success', False)
                logger.debug(f"滑动 ({x1},{y1}) -> ({x2},{y2}): {success}")
                return success

            return False

        except Exception as e:
            logger.error(f"滑动失败: {e}")
            return False

    def input_text(self, text: str) -> bool:
        """
        输入文字

        Args:
            text: 要输入的文字

        Returns:
            是否成功
        """
        try:
            response = requests.post(
                f"{self.helper_url}/input",
                json={'text': text},
                timeout=5
            )

            if response.status_code == 200:
                data = response.json()
                success = data.get('success', False)
                logger.debug(f"输入文字: {success}")
                return success

            return False

        except Exception as e:
            logger.error(f"输入失败: {e}")
            return False


# 测试代码
if __name__ == '__main__':
    print("测试远程手机控制器...")
    print(f"手机地址: {os.getenv('PHONE_HELPER_URL', 'http://localhost:8080')}")
    print("")

    try:
        controller = PhoneControllerRemote()

        # 测试截图
        print("测试截图...")
        img = controller.screenshot()
        if img:
            print(f"✅ 截图成功: {img.size}")
            img.save('test_screenshot.png')
            print("   截图已保存: test_screenshot.png")
        else:
            print("❌ 截图失败")

        print("")

        # 测试点击
        print("测试点击中心位置...")
        success = controller.tap(500, 1000)
        if success:
            print("✅ 点击成功")
        else:
            print("❌ 点击失败")

        print("")
        print("测试完成！")

    except Exception as e:
        print(f"❌ 错误: {e}")
