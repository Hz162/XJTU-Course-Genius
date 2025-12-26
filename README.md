# XJTU Course Genius (qk3)

西安交通大学选课辅助工具 / XJTU Course Selection Assistant

## 简介 / Introduction

这是一个基于 Python (PyQt5 + Selenium + Requests) 开发的西安交通大学自动选课工具。
它结合了 Selenium 的浏览器指纹获取能力和 Requests 的高效网络请求，支持多种选课模式和 MFA 二次验证。

## 功能特性 / Features

- **图形化界面 (GUI)**: 基于 PyQt5 开发，操作简单直观。
- **高效选课**: 使用 `requests` 库进行核心选课操作，速度快于纯浏览器模拟。
- **MFA 支持**: 完美支持学校的统一身份认证二次验证（短信/邮箱验证码）。
- **智能驱动管理**:
  - 自动检测本地 Edge 浏览器版本。
  - **国内加速**: 默认使用淘宝镜像源 (npmmirror) 下载 Edge WebDriver，解决国内网络无法下载驱动的问题。
  - 自动处理 SSL 证书错误。
- **多轮次支持**: 支持选择不同的选课轮次。
- **冲突课程处理**: 支持添加和删除冲突课程。
- **多种选课类型**: 支持主修推荐、方案内跨年级、方案外、基础通识、体育课等多种类型。

## 环境要求 / Requirements

- **操作系统**: Windows (推荐 Windows 10/11)
- **浏览器**: Microsoft Edge (必须安装)
- **Python**: 3.8+ (如果从源码运行)

## 安装与运行 / Installation & Usage

### 方式一：使用打包好的程序 (推荐)

直接下载并运行 `XJTUCourseGeniusSetup.exe` 安装包（如果有发布）。

### 方式二：从源码运行

1. **克隆仓库**

    ```bash
    git clone https://github.com/Hz162/qk3.git
    cd qk3
    ```

2. **安装依赖**

    ```bash
    pip install -r requirements.txt
    ```

3. **运行程序**

    ```bash
    python login.py
    ```

## 常见问题 / FAQ

**Q: 启动时提示驱动下载失败？**
A: 程序内置了多重容错机制：

1. 优先检测本地 Edge 版本并从淘宝镜像下载对应驱动。
2. 如果自动下载失败，程序会尝试查找根目录下的 `msedgedriver.exe`。
3. 您可以手动下载对应版本的 `msedgedriver.exe` 放到程序目录下。下载地址：[淘宝镜像源](https://npmmirror.com/mirrors/edgedriver/)

**Q: 登录时提示“用户取消或验证失败”？**
A: 这通常是因为触发了 MFA 二次验证但未完成。请在弹出的验证窗口中选择验证方式（短信或邮箱），发送验证码并填写正确，点击“验证”按钮，等待提示“验证成功”后再关闭窗口。

## 免责声明 / Disclaimer

本工具仅供学习交流使用，请勿用于非法用途或对学校服务器造成攻击。使用本工具产生的任何后果由用户自行承担。
