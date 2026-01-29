"""
手机白名单管理模块
支持多台手机的添加、删除、切换功能
"""

import json
import logging
import uuid
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
from threading import Lock

logger = logging.getLogger(__name__)


class PhoneManager:
    """
    手机白名单管理器（单例模式）
    管理多台手机的配置信息和当前激活状态
    """

    _instance = None
    _lock = Lock()

    def __new__(cls, whitelist_file: Path):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self, whitelist_file: Path):
        if hasattr(self, '_initialized'):
            return

        self._initialized = True
        self.whitelist_file = whitelist_file
        self.phones: Dict[str, dict] = {}
        self.current_id: Optional[str] = None

        # 加载白名单
        self._load_whitelist()

    def _load_whitelist(self):
        """从文件加载白名单"""
        if not self.whitelist_file.exists():
            logger.info("手机白名单文件不存在，创建新文件")
            self._save_whitelist()
            return

        try:
            with open(self.whitelist_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                self.phones = {p['id']: p for p in data.get('phones', [])}
                self.current_id = data.get('current_id')

            logger.info(f"已加载 {len(self.phones)} 台手机配置")
            if self.current_id:
                logger.info(f"当前激活手机: {self.phones.get(self.current_id, {}).get('name', 'Unknown')}")
        except Exception as e:
            logger.error(f"加载手机白名单失败: {e}", exc_info=True)
            self.phones = {}
            self.current_id = None

    def _save_whitelist(self):
        """保存白名单到文件"""
        try:
            data = {
                'phones': list(self.phones.values()),
                'current_id': self.current_id
            }

            self.whitelist_file.parent.mkdir(parents=True, exist_ok=True)

            with open(self.whitelist_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)

            logger.debug(f"手机白名单已保存: {len(self.phones)} 台手机")
        except Exception as e:
            logger.error(f"保存手机白名单失败: {e}", exc_info=True)

    def add_phone(self, name: str, url: str, description: str = "") -> dict:
        """
        添加新手机到白名单

        Args:
            name: 手机名称
            url: AutoGLM Helper 的 URL (如 http://192.168.1.100:8080)
            description: 手机描述（可选）

        Returns:
            新添加的手机信息字典
        """
        # 验证 URL 格式
        if not url.startswith(('http://', 'https://')):
            raise ValueError("URL 必须以 http:// 或 https:// 开头")

        # 检查是否已存在相同 URL
        for phone in self.phones.values():
            if phone['url'] == url:
                raise ValueError(f"手机 URL 已存在: {phone['name']}")

        # 创建新手机记录
        phone_id = str(uuid.uuid4())
        phone = {
            'id': phone_id,
            'name': name,
            'url': url,
            'description': description,
            'added_at': datetime.now().isoformat(),
            'is_active': False
        }

        # 如果是第一台手机，自动设为激活状态
        if not self.phones:
            phone['is_active'] = True
            self.current_id = phone_id
            logger.info(f"添加第一台手机并自动激活: {name}")

        self.phones[phone_id] = phone
        self._save_whitelist()

        logger.info(f"已添加手机: {name} ({url})")
        return phone

    def remove_phone(self, phone_id: str) -> bool:
        """
        从白名单删除手机

        Args:
            phone_id: 手机 ID

        Returns:
            是否删除成功
        """
        if phone_id not in self.phones:
            logger.warning(f"手机不存在: {phone_id}")
            return False

        phone = self.phones[phone_id]
        name = phone['name']

        # 如果删除的是当前激活手机，清除激活状态
        if self.current_id == phone_id:
            self.current_id = None
            logger.warning(f"删除了当前激活的手机: {name}")

            # 如果还有其他手机，自动激活第一台
            if len(self.phones) > 1:
                remaining = [pid for pid in self.phones.keys() if pid != phone_id]
                if remaining:
                    self.current_id = remaining[0]
                    self.phones[self.current_id]['is_active'] = True
                    logger.info(f"自动激活手机: {self.phones[self.current_id]['name']}")

        del self.phones[phone_id]
        self._save_whitelist()

        logger.info(f"已删除手机: {name}")
        return True

    def get_phones(self) -> List[dict]:
        """
        获取所有手机列表

        Returns:
            手机信息列表
        """
        return list(self.phones.values())

    def get_phone(self, phone_id: str) -> Optional[dict]:
        """
        获取指定手机信息

        Args:
            phone_id: 手机 ID

        Returns:
            手机信息字典，不存在返回 None
        """
        return self.phones.get(phone_id)

    def set_active_phone(self, phone_id: str) -> bool:
        """
        设置当前激活的手机

        Args:
            phone_id: 手机 ID

        Returns:
            是否设置成功
        """
        if phone_id not in self.phones:
            logger.warning(f"手机不存在: {phone_id}")
            return False

        # 取消所有手机的激活状态
        for phone in self.phones.values():
            phone['is_active'] = False

        # 激活指定手机
        self.phones[phone_id]['is_active'] = True
        self.current_id = phone_id
        self._save_whitelist()

        logger.info(f"已激活手机: {self.phones[phone_id]['name']}")
        return True

    def get_active_phone(self) -> Optional[dict]:
        """
        获取当前激活的手机

        Returns:
            当前激活的手机信息，无激活手机返回 None
        """
        if self.current_id and self.current_id in self.phones:
            return self.phones[self.current_id]
        return None

    def get_active_phone_url(self) -> Optional[str]:
        """
        获取当前激活手机的 URL

        Returns:
            当前激活手机的 URL，无激活手机返回 None
        """
        active_phone = self.get_active_phone()
        if active_phone:
            return active_phone['url']
        return None
