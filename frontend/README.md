# XJTU Course Genius — Flutter Frontend

基于 Flutter 3.44+ 开发的西安交通大学选课系统桌面客户端，支持 Windows / Linux / macOS。提供 Material 3 风格的现代化 UI，集成 IME 输入法自动切换。

## 架构概览

```
lib/
├── main.dart                        # 应用入口，MaterialApp 配置
├── models/
│   └── course.dart                  # 数据模型 (CourseInfo, BatchInfo, SelectionStatus)
├── services/
│   ├── api_service.dart             # HTTP API 客户端，对接 Go 后端
│   └── ime_service.dart             # IME 输入法切换服务（焦点计数 + 延迟恢复）
├── pages/
│   ├── login_page.dart              # CAS 登录页（含验证码、MFA 跳转、账户选择）
│   ├── mfa_page.dart                # MFA 二次认证页（短信/邮箱验证码）
│   ├── round_page.dart              # 轮次选择页
│   └── home_page.dart               # 主页：课程浏览 + 选课面板 + 抢课控制
├── widgets/
│   └── sidebar.dart                 # 侧边栏：导航 + 校区切换
└── theme/
    └── app_theme.dart               # 主题色、字体、圆角、阴影等全局样式
```

## 目录结构

```
frontend/
├── pubspec.yaml                     # Flutter 依赖配置
├── lib/                             # Dart 源码
├── windows/runner/                  # Windows 原生代码
│   ├── flutter_window.h             # 自定义 IME 方法通道声明
│   └── flutter_window.cpp           # IME 切换实现（HWND_BROADCAST + KLF_ACTIVATE）
├── linux/runner/
│   └── my_application.cc            # Linux IME 切换（setxkbmap + GTK focus 事件）
├── macos/Runner/
│   └── MainFlutterWindow.swift      # macOS IME 切换（TISSelectInputSource）
├── web/iife.min.js                  # FingerprintJS 库（供原版 Python 使用）
└── test/
    ├── api_service_test.dart         # API 服务单元测试（24 个测试用例）
    └── widget_test.dart              # 基础 Widget 测试
```

## 核心模块详解

### 1. API 服务 (`lib/services/api_service.dart`)

封装所有后端 API 调用，统一错误处理。

```dart
class ApiService {
  static const baseUrl = 'http://127.0.0.1:18720/api';

  // 认证
  Future<Map> login(account, password, {captcha})
  Future<List<int>> getCaptchaImage()
  Future<Map> mfaInit(method) / mfaSend() / mfaVerify(code)
  Future<Map> chooseAccount(accountType)

  // 选课数据
  Future<List<BatchInfo>> getBatches()
  Future<Map> enterRound(batchCode)
  Future<List> getSelectedCourses()
  Future<Map> queryCourses(type, {keyword})

  // 抢课
  Future<void> startSelection() / stopSelection()
  Future<SelectionStatus> getSelectionStatus()

  // 配置与会话
  Future<Map> getConfig() / saveConfig(course, delcourses)
  Future<List> getCampusList() / setCampus(campus)
  Future<bool> checkSession() / relogin()
}
```

### 2. 登录流程 (`lib/pages/login_page.dart`)

```
用户输入账号密码 → POST /api/login
  │
  ├── {success: true}
  │   └── 跳转 RoundPage（轮次选择）
  │
  ├── {captcha_required: true}
  │   └── 显示验证码输入框 + 图片 → 用户输入 → 重新登录
  │
  ├── {mfa_required: true}
  │   └── 跳转 MfaPage → 选择验证方式 → 发送验证码 → 输入验证 → 回到登录页
  │
  └── {account_choice_required: true}
      └── 弹出选择对话框 → 选本科/研究生 → chooseAccount → 跳转 RoundPage
```

支持 `Ctrl+Enter` 快捷键提交登录。

### 3. MFA 页面 (`lib/pages/mfa_page.dart`)

- 支持手机短信 (`securephone`) 和邮箱验证 (`secureemail`)
- 60 秒倒计时防重复发送
- 自动调用 `mfaInit` → `mfaSend` → `mfaVerify` 三步流程

### 4. 主页 (`lib/pages/home_page.dart`)

**侧边栏导航**（5 种课程类型 + 已选课程 + 选课控制 + 配置管理）：

| 导航项 | 课程类型 | 后端 API |
|--------|----------|----------|
| 已选课程 | — | `courses/selected` |
| 主修推荐 | TJKC | `courses/query/TJKC` |
| 方案内 | FANKC | `courses/query/FANKC` |
| 方案外 | FAWKC | `courses/query/FAWKC` |
| 基础通识 | XGXK | `courses/query/XGXK` |
| 体育 | TYKC | `courses/query/TYKC` |

底部校区选择器动态加载 `campus` API 返回的校区列表。

**课程卡片**：

- 点击可查看课程详情（Dialog 弹窗，显示班号、教师、地点、容量）
- `已选课程` 视图额外显示课程类型彩色标签
- 使用 `classType` 字段映射颜色（主修=蓝、方案内=绿、方案外=橙、通识=紫、体育=青）

**选课面板**：

- 配置页：添加/删除待抢课程 + 冲突课程
- 选课控制页：开始/停止抢课，实时状态显示
- 使用 `flags[]` 数组逐个判断课程状态（而非顺序假设）
- 日志面板显示后端实时日志

### 5. IME 输入法切换 (`lib/services/ime_service.dart`)

专为中文用户设计，在输入框获得焦点时自动切换到英文，失去焦点时恢复中文。

**核心机制**：

```
焦点获得 → focusCount++ → 若未保存 → saveCurrentIme → switchToEnglish
焦点失去 → focusCount-- → 若 count==0 → 50ms 延迟 → restoreIme
App 切后台 → 取消延迟定时器（C++ 侧处理系统级恢复）
```

**焦点计数**：多个输入框切换时（如账号→密码），新框 focus（count=2）先于旧框 blur（count=1），count 不归零阻止误恢复。

### 6. Windows IME 实现 (`windows/runner/flutter_window.cpp`)

```
saveCurrentIme    → GetKeyboardLayout(0)          保存当前 HKL
switchToEnglish   → LoadKeyboardLayout("00000409") 切换到英文
restoreIme        → ActivateKeyboardLayout(saved)  恢复中文
App 失去焦点      → HWND_BROADCAST WM_INPUTLANGCHANGEREQUEST 广播中文恢复
App 获得焦点      → ActivateKeyboardLayout(english) 切回英文
```

使用 `KLF_ACTIVATE`（线程级）而非 `KLF_SETFORPROCESS`（进程级），避免影响其他应用。

## 主题系统 (`lib/theme/app_theme.dart`)

```dart
// 主色调
primaryColor   = Color(0xFF1565C0)   // 蓝色
successColor   = Color(0xFF4CAF50)   // 绿色
warningColor   = Color(0xFFFF9800)   // 橙色
accentPurple   = Color(0xFF7C4DFF)   // 紫色
accentTeal     = Color(0xFF26A69A)   // 青色
accentPink     = Color(0xFFE91E63)   // 粉色

// 课程类型 → 颜色映射
accentForType('TJKC')  → primaryColor   (蓝色)
accentForType('FANKC') → successColor   (绿色)
accentForType('FAWKC') → warningColor   (橙色)
accentForType('XGXK')  → accentPurple   (紫色)
accentForType('TYKC')  → accentTeal     (青色)

// 圆角
radiusSm = 6.0, radiusMd = 10.0, radiusLg = 14.0

// 字体
fontFamily: 'NotoSansSC' (思源黑体，支持中英文混排)
```

## 数据模型 (`lib/models/course.dart`)

```dart
class CourseInfo {
  String teachingClassId;  // 教学班 ID
  String courseName;       // 课程名称
  String teacherName;      // 教师
  String teachingPlace;    // 上课地点
  String classType;        // 课程类型 (TJKC/FANKC/...)
  String campus;           // 校区代码
}

class BatchInfo {
  String code;             // 轮次代码
  String name;             // 轮次名称
  String canSelect;        // "1"=可选 "0"=不可选
}

class SelectionStatus {
  bool running;            // 是否正在抢课
  int totalCourse;         // 总课程数
  List<int> flags;         // 每门课状态 (0=未抢到 1=已抢到)
  int progress;            // 已抢到数量
  List<String> log;        // 后端日志
}
```

## 编译与部署

### 环境要求

- Flutter SDK 3.44+
- Windows: Visual Studio 2019+ (Build Tools) 或 Windows SDK
- Linux: GTK 3.0+ 开发库
- macOS: Xcode + CocoaPods

### 依赖

```yaml
dependencies:
  flutter: sdk
  http: ^1.2.0       # HTTP 客户端
  # Material 3 原生支持，无需额外 UI 库
```

### 编译

```bash
cd frontend

# Windows
flutter build windows --debug    # 调试版
flutter build windows --release  # 发布版

# Linux
flutter build linux

# macOS
flutter build macos
```

### 运行

```bash
# 确保后端已启动 (127.0.0.1:18720)
cd frontend
flutter run -d windows
```

### 测试

```bash
# 运行所有测试（24 个 API 测试 + 1 个 Widget 测试）
flutter test

# 代码分析
dart analyze lib/
```

## 平台特定说明

### Windows

- Edge WebView2 运行时（通常已预装）
- IME 切换使用 Win32 API，仅 Windows 平台生效
- 编译产物：`build/windows/x64/runner/Debug/xjtu_course_genius.exe`

### Linux

- 需要 `libgtk-3-dev` 和 `setxkbmap` 命令
- IME 通过 `setxkbmap` 命令切换键盘布局
- GTK 窗口的 `focus-out-event` / `focus-in-event` 处理应用切换

### macOS

- IME 通过 `TISSelectInputSource` API 切换输入源
- `NSWindow.didResignKeyNotification` 处理窗口失去焦点
- `NSWindow.didBecomeKeyNotification` 处理窗口重获焦点

## 前后端通信

| 前端组件 | API 调用 | 后端处理 |
|----------|----------|----------|
| 登录页 | `POST /api/login` | CAS 登录 → 返回 token |
| MFA 页 | `/mfa/init` → `/mfa/send` → `/mfa/verify` | CAS MFA 流程 |
| 轮次页 | `GET /batches` → `POST /batches/select` | xkfw API |
| 主页课程 | `GET /courses/query/{type}` | xkfw 分页查询 |
| 主页已选 | `GET /courses/selected` | xkfw 已选查询 |
| 选课面板 | `POST /selection/start` → `GET /selection/status` | 抢课引擎 |
| 配置 | `POST /config` → `GET /config` | JSON 文件存储 |
