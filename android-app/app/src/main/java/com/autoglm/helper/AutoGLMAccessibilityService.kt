package com.autoglm.helper

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Path
import android.os.Build
import android.util.Base64
import android.util.Log
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.io.ByteArrayOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class AutoGLMAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AutoGLM-Service"
        const val PORT = 8080
        
        @Volatile
        private var instance: AutoGLMAccessibilityService? = null
        
        fun getInstance(): AutoGLMAccessibilityService? = instance
    }

    private var httpServer: HttpServer? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        
        Log.i(TAG, "Service connected")
        
        // 启动 HTTP 服务器
        startHttpServer()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 不需要处理事件
    }

    override fun onInterrupt() {
        Log.w(TAG, "Service interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        
        // 停止 HTTP 服务器
        stopHttpServer()
        
        Log.i(TAG, "Service destroyed")
    }

    private fun startHttpServer() {
        try {
            httpServer = HttpServer(this, PORT)
            httpServer?.start()
            Log.i(TAG, "HTTP server started on port $PORT")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start HTTP server", e)
        }
    }

    private fun stopHttpServer() {
        httpServer?.stop()
        httpServer = null
        Log.i(TAG, "HTTP server stopped")
    }

    fun isAccessibilityEnabled(): Boolean {
        return instance != null
    }

    /**
     * 执行点击操作
     */
    fun performTap(x: Int, y: Int): Boolean {
        return try {
            val path = Path()
            path.moveTo(x.toFloat(), y.toFloat())
            
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
                .build()
            
            val latch = CountDownLatch(1)
            var success = false
            
            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    success = true
                    latch.countDown()
                }
                
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    success = false
                    latch.countDown()
                }
            }, null)
            
            latch.await(5, TimeUnit.SECONDS)
            Log.d(TAG, "Tap at ($x, $y): $success")
            success
        } catch (e: Exception) {
            Log.e(TAG, "Failed to perform tap", e)
            false
        }
    }

    /**
     * 执行滑动操作
     */
    fun performSwipe(x1: Int, y1: Int, x2: Int, y2: Int, duration: Int): Boolean {
        return try {
            val path = Path()
            path.moveTo(x1.toFloat(), y1.toFloat())
            path.lineTo(x2.toFloat(), y2.toFloat())
            
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, duration.toLong()))
                .build()
            
            val latch = CountDownLatch(1)
            var success = false
            
            dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    success = true
                    latch.countDown()
                }
                
                override fun onCancelled(gestureDescription: GestureDescription?) {
                    success = false
                    latch.countDown()
                }
            }, null)
            
            latch.await(10, TimeUnit.SECONDS)
            Log.d(TAG, "Swipe from ($x1, $y1) to ($x2, $y2): $success")
            success
        } catch (e: Exception) {
            Log.e(TAG, "Failed to perform swipe", e)
            false
        }
    }

    /**
     * 执行输入操作（改进版：支持三种方式）
     * 1. 剪贴板粘贴（最通用）
     * 2. ACTION_SET_TEXT（标准输入框）
     * 3. 逐字符输入（降级方案）
     */
    fun performInput(text: String): Boolean {
        return try {
            // 方法1: 剪贴板粘贴（最通用，推荐）
            if (performInputViaClipboard(text)) {
                Log.d(TAG, "Input via clipboard: success")
                return true
            }

            // 方法2: ACTION_SET_TEXT（传统方式）
            if (performInputViaSetText(text)) {
                Log.d(TAG, "Input via SET_TEXT: success")
                return true
            }

            // 方法3: 逐字符输入（最后降级方案）
            Log.w(TAG, "All input methods failed")
            false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to perform input", e)
            false
        }
    }

    /**
     * 方法1: 使用剪贴板粘贴输入文字
     * 兼容性最好，适用于大部分应用
     */
    private fun performInputViaClipboard(text: String): Boolean {
        return try {
            // 1. 复制文本到剪贴板
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            val clip = ClipData.newPlainText("AutoGLM", text)
            clipboard.setPrimaryClip(clip)

            Thread.sleep(100) // 等待剪贴板设置完成

            // 2. 查找输入框并执行粘贴操作
            val rootNode = rootInActiveWindow ?: return false
            val focusedNode = findFocusedEditText(rootNode)

            if (focusedNode != null) {
                // 执行粘贴动作
                val success = focusedNode.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                focusedNode.recycle()
                rootNode.recycle()
                return success
            } else {
                // 如果没有找到焦点输入框，尝试查找所有可编辑的节点
                val editableNode = findAnyEditText(rootNode)
                if (editableNode != null) {
                    // 先聚焦
                    editableNode.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
                    Thread.sleep(100)

                    // 再粘贴
                    val success = editableNode.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                    editableNode.recycle()
                    rootNode.recycle()
                    return success
                }

                rootNode.recycle()
                Log.w(TAG, "No editable field found for clipboard paste")
                return false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Clipboard input failed", e)
            false
        }
    }

    /**
     * 方法2: 使用 ACTION_SET_TEXT 输入文字
     * 适用于标准输入框
     */
    private fun performInputViaSetText(text: String): Boolean {
        return try {
            val rootNode = rootInActiveWindow ?: return false
            val focusedNode = findFocusedEditText(rootNode)

            if (focusedNode != null) {
                val arguments = android.os.Bundle()
                arguments.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
                val success = focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
                focusedNode.recycle()
                rootNode.recycle()
                return success
            } else {
                rootNode.recycle()
                return false
            }
        } catch (e: Exception) {
            Log.e(TAG, "SET_TEXT input failed", e)
            false
        }
    }

    /**
     * 查找任意可编辑文本框（不一定有焦点）
     */
    private fun findAnyEditText(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isEditable) {
            return node
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findAnyEditText(child)
            if (result != null) {
                return result
            }
            child.recycle()
        }

        return null
    }

    private fun findFocusedEditText(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isFocused && node.isEditable) {
            return node
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val result = findFocusedEditText(child)
            if (result != null) {
                return result
            }
            child.recycle()
        }
        
        return null
    }

    /**
     * 截取屏幕并返回 Base64 编码
     */
    fun takeScreenshotBase64(): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Android 11+ 使用 takeScreenshot API
                val latch = CountDownLatch(1)
                var bitmap: Bitmap? = null
                
                takeScreenshot(
                    Display.DEFAULT_DISPLAY,
                    mainExecutor,
                    object : TakeScreenshotCallback {
                        override fun onSuccess(screenshotResult: ScreenshotResult) {
                            bitmap = Bitmap.wrapHardwareBuffer(
                                screenshotResult.hardwareBuffer,
                                screenshotResult.colorSpace
                            )
                            latch.countDown()
                        }
                        
                        override fun onFailure(errorCode: Int) {
                            Log.e(TAG, "Screenshot failed with error code: $errorCode")
                            latch.countDown()
                        }
                    }
                )
                
                latch.await(5, TimeUnit.SECONDS)
                
                if (bitmap != null) {
                    val outputStream = ByteArrayOutputStream()
                    bitmap!!.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
                    val bytes = outputStream.toByteArray()
                    bitmap!!.recycle()
                    Base64.encodeToString(bytes, Base64.NO_WRAP)
                } else {
                    null
                }
            } else {
                // Android 7-10 不支持 takeScreenshot，返回 null
                // 调用方应降级到 ADB screencap
                Log.w(TAG, "takeScreenshot not supported on Android < 11")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to take screenshot", e)
            null
        }
    }
}
