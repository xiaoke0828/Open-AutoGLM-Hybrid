#!/usr/bin/env python3
"""
输入功能诊断脚本
测试手机输入功能是否正常
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'mac-server'))

from phone_controller_remote import PhoneControllerRemote
import time

def test_input():
    """测试输入功能"""
    print("=" * 60)
    print("📱 手机输入功能诊断")
    print("=" * 60)
    print()

    # 从环境变量获取手机 URL
    phone_url = os.getenv('PHONE_HELPER_URL', 'http://192.168.110.198:8080')
    print(f"手机地址: {phone_url}")
    print()

    try:
        # 初始化控制器
        print("1. 连接手机...")
        controller = PhoneControllerRemote(helper_url=phone_url)
        print("   ✅ 连接成功")
        print()

        # 获取截图
        print("2. 截取当前屏幕...")
        img = controller.screenshot()
        if img:
            print(f"   ✅ 截图成功: {img.size}")
            img.save('input_test_before.png')
            print("   截图已保存: input_test_before.png")
        else:
            print("   ❌ 截图失败")
        print()

        # 提示用户
        print("3. 准备测试输入...")
        print("   ⚠️ 请在手机上打开一个输入框（如微信/备忘录）")
        print("   ⚠️ 点击输入框使其获得焦点（显示光标）")
        input("   准备好后按 Enter 继续...")
        print()

        # 测试输入
        print("4. 测试输入文字...")
        test_text = "Hello 你好 123"
        print(f"   输入内容: {test_text}")

        success = controller.input_text(test_text)

        if success:
            print("   ✅ API 返回成功")
        else:
            print("   ❌ API 返回失败")

        time.sleep(1)

        # 再次截图对比
        print()
        print("5. 截取输入后的屏幕...")
        img_after = controller.screenshot()
        if img_after:
            print(f"   ✅ 截图成功: {img_after.size}")
            img_after.save('input_test_after.png')
            print("   截图已保存: input_test_after.png")
        else:
            print("   ❌ 截图失败")

        print()
        print("=" * 60)
        print("📊 诊断结果")
        print("=" * 60)

        if success:
            print("✅ 输入 API 调用成功")
            print("   请检查手机屏幕是否显示输入的文字")
            print("   对比前后截图: input_test_before.png vs input_test_after.png")
        else:
            print("❌ 输入 API 调用失败")
            print()
            print("可能的原因：")
            print("1. 输入框没有获得焦点（没有显示光标）")
            print("2. 某些应用的输入框不支持无障碍输入")
            print("3. 输入框类型不兼容（如密码框）")
            print()
            print("建议：")
            print("- 使用改进版输入方案（剪贴板粘贴）")
            print("- 或使用 ADB input 命令")

        print()

    except Exception as e:
        print(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    test_input()
