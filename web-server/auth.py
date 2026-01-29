"""
认证中间件
提供简单的 Token 认证
"""

from functools import wraps
from flask import request, jsonify
from config import AUTH_TOKEN
import logging

logger = logging.getLogger(__name__)

# 请求计数器（用于简单的 rate limiting）
request_counts = {}


def require_auth(f):
    """
    认证装饰器
    检查请求头中的 Authorization: Bearer <token>
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # 获取 Authorization 头
        auth_header = request.headers.get('Authorization', '')

        # 检查格式
        if not auth_header.startswith('Bearer '):
            logger.warning(f"认证失败: 缺少 Bearer token, IP: {request.remote_addr}")
            return jsonify({
                'error': '未授权访问',
                'message': '请提供有效的认证 Token'
            }), 401

        # 提取 token
        token = auth_header[7:]  # 去掉 "Bearer " 前缀

        # 验证 token
        if token != AUTH_TOKEN:
            logger.warning(f"认证失败: Token 无效, IP: {request.remote_addr}")
            return jsonify({
                'error': '未授权访问',
                'message': 'Token 无效'
            }), 401

        # 认证成功
        logger.debug(f"认证成功, IP: {request.remote_addr}")
        return f(*args, **kwargs)

    return decorated_function


def simple_rate_limit(max_requests=10, window_seconds=60):
    """
    简单的请求限速装饰器
    限制每个 IP 在时间窗口内的请求次数
    """
    import time

    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            client_ip = request.remote_addr
            current_time = time.time()

            # 清理过期的计数
            if client_ip in request_counts:
                request_counts[client_ip] = [
                    timestamp for timestamp in request_counts[client_ip]
                    if current_time - timestamp < window_seconds
                ]
            else:
                request_counts[client_ip] = []

            # 检查是否超过限制
            if len(request_counts[client_ip]) >= max_requests:
                logger.warning(
                    f"请求限速触发: IP {client_ip} "
                    f"在 {window_seconds} 秒内请求 {len(request_counts[client_ip])} 次"
                )
                return jsonify({
                    'error': '请求过于频繁',
                    'message': f'请在 {window_seconds} 秒后重试'
                }), 429

            # 记录本次请求
            request_counts[client_ip].append(current_time)

            return f(*args, **kwargs)

        return decorated_function

    return decorator


def log_request():
    """
    记录请求信息（中间件）
    """
    logger.info(
        f"{request.method} {request.path} - "
        f"IP: {request.remote_addr} - "
        f"User-Agent: {request.headers.get('User-Agent', 'Unknown')}"
    )
