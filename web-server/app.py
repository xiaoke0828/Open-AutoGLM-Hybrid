"""
AutoGLM Web 界面 - Flask 主应用
提供任务提交、实时日志、截图展示功能
"""

import logging
import sys
from flask import Flask, render_template, request, jsonify, Response
from flask_cors import CORS

# 导入本地模块
from config import (
    WEB_HOST, WEB_PORT, AUTH_TOKEN, LOG_FILE,
    get_config_summary, validate_config
)
from auth import require_auth, simple_rate_limit, log_request
from tasks import task_manager, TaskStatus

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# 创建 Flask 应用
app = Flask(__name__)
CORS(app)  # 允许跨域（方便开发）

# 在每个请求前记录日志
@app.before_request
def before_request():
    log_request()


# ==================== 页面路由 ====================

@app.route('/')
def index():
    """主页 - 任务提交界面"""
    return render_template('index.html', auth_token=AUTH_TOKEN)


@app.route('/task/<task_id>')
def task_detail(task_id):
    """任务详情页 - 实时日志和截图"""
    task = task_manager.get_task(task_id)
    if not task:
        return "任务不存在", 404
    return render_template('task.html', task=task, auth_token=AUTH_TOKEN)


@app.route('/history')
def history():
    """历史记录页"""
    return render_template('history.html', auth_token=AUTH_TOKEN)


# ==================== API 路由 ====================

@app.route('/api/config', methods=['GET'])
def get_config():
    """获取配置信息（隐藏敏感信息）"""
    return jsonify(get_config_summary())


@app.route('/api/health', methods=['GET'])
def health_check():
    """健康检查"""
    return jsonify({
        'status': 'ok',
        'message': 'AutoGLM Web 服务运行正常',
        'current_task': task_manager.get_current_task().id if task_manager.get_current_task() else None
    })


@app.route('/api/tasks', methods=['POST'])
@require_auth
@simple_rate_limit(max_requests=10, window_seconds=60)
def submit_task():
    """
    提交新任务
    请求体: {"description": "任务描述"}
    """
    try:
        data = request.get_json()
        description = data.get('description', '').strip()

        if not description:
            return jsonify({'error': '任务描述不能为空'}), 400

        if len(description) > 500:
            return jsonify({'error': '任务描述过长（最大 500 字符）'}), 400

        # 提交任务
        task = task_manager.submit_task(description)

        return jsonify({
            'success': True,
            'task_id': task.id,
            'message': '任务已提交',
            'task_url': f'/task/{task.id}'
        }), 201

    except Exception as e:
        logger.error(f"提交任务失败: {e}", exc_info=True)
        return jsonify({'error': f'提交失败: {str(e)}'}), 500


@app.route('/api/tasks/<task_id>', methods=['GET'])
@require_auth
def get_task(task_id):
    """获取任务详情"""
    task = task_manager.get_task(task_id)
    if not task:
        return jsonify({'error': '任务不存在'}), 404

    return jsonify(task.to_dict())


@app.route('/api/tasks', methods=['GET'])
@require_auth
def get_tasks():
    """获取任务列表"""
    limit = request.args.get('limit', 20, type=int)
    tasks = task_manager.get_recent_tasks(limit)
    return jsonify([task.to_dict() for task in tasks])


@app.route('/api/tasks/<task_id>/logs', methods=['GET'])
def get_task_logs_stream(task_id):
    """
    实时日志流（Server-Sent Events）
    客户端通过 EventSource 连接此端点接收实时日志
    """

    def event_stream():
        """生成 SSE 事件流"""
        task = task_manager.get_task(task_id)
        if not task:
            yield f"data: {jsonify({'error': '任务不存在'}).get_data(as_text=True)}\n\n"
            return

        # 发送初始状态
        yield f"data: {jsonify({'type': 'init', 'task': task.to_dict()}).get_data(as_text=True)}\n\n"

        # 记录已发送的日志数量
        sent_logs = 0

        # 持续推送更新
        import time
        while True:
            # 检查任务状态
            current_task = task_manager.get_task(task_id)
            if not current_task:
                break

            # 发送新日志
            if len(current_task.logs) > sent_logs:
                new_logs = current_task.logs[sent_logs:]
                for log in new_logs:
                    yield f"data: {jsonify({'type': 'log', 'message': log}).get_data(as_text=True)}\n\n"
                sent_logs = len(current_task.logs)

            # 发送截图更新
            if current_task.screenshot:
                yield f"data: {jsonify({'type': 'screenshot', 'data': current_task.screenshot}).get_data(as_text=True)}\n\n"

            # 发送状态更新
            yield f"data: {jsonify({'type': 'status', 'status': current_task.status}).get_data(as_text=True)}\n\n"

            # 如果任务完成或失败，结束流
            if current_task.status in [TaskStatus.COMPLETED, TaskStatus.FAILED]:
                yield f"data: {jsonify({'type': 'end', 'status': current_task.status}).get_data(as_text=True)}\n\n"
                break

            # 每秒检查一次
            time.sleep(1)

    return Response(
        event_stream(),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'X-Accel-Buffering': 'no'  # 禁用 Nginx 缓冲
        }
    )


@app.route('/api/current-task', methods=['GET'])
@require_auth
def get_current_task():
    """获取当前正在执行的任务"""
    task = task_manager.get_current_task()
    if not task:
        return jsonify({'message': '当前无任务执行'}), 404

    return jsonify(task.to_dict())


# ==================== 错误处理 ====================

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': '资源不存在'}), 404


@app.errorhandler(500)
def internal_error(error):
    logger.error(f"服务器内部错误: {error}", exc_info=True)
    return jsonify({'error': '服务器内部错误'}), 500


# ==================== 主入口 ====================

def main():
    """启动 Web 服务"""
    # 验证配置
    config_errors = validate_config()
    if config_errors:
        logger.error("配置验证失败:")
        for error in config_errors:
            logger.error(f"  {error}")
        logger.warning("部分功能可能不可用")

    # 打印配置信息
    logger.info("=" * 60)
    logger.info("AutoGLM Web 服务启动")
    logger.info("=" * 60)
    config = get_config_summary()
    for key, value in config.items():
        logger.info(f"  {key}: {value}")
    logger.info("=" * 60)
    logger.info(f"认证 Token: {AUTH_TOKEN}")
    logger.info(f"访问地址: http://{WEB_HOST}:{WEB_PORT}")
    logger.info("=" * 60)

    # 启动任务管理器
    task_manager.start_worker()

    # 启动 Flask 应用
    try:
        app.run(
            host=WEB_HOST,
            port=WEB_PORT,
            debug=False,
            threaded=True
        )
    except KeyboardInterrupt:
        logger.info("收到中断信号，正在关闭...")
    finally:
        task_manager.stop_worker()
        logger.info("服务已关闭")


if __name__ == '__main__':
    main()
