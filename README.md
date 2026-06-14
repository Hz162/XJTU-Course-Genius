# XJTU Course Genius

西安交通大学选课辅助工具 — 新版前后端分离架构。

```
┌─────────────────────────┐     ┌──────────────────────────┐
│   Flutter 前端           │────▶│   Go 后端 (chi + resty)   │────▶  xkfw.xjtu.edu.cn
│   Windows / Linux / macOS│     │   127.0.0.1:18720        │      (CAS + 选课 API)
│   Material 3 UI          │     │   CAS 登录 + 抢课引擎     │
└─────────────────────────┘     └──────────────────────────┘
```

## 项目结构

```
XJTU-Course-Genius/
├── frontend/                  # Flutter 桌面客户端
│   ├── lib/                   #   Dart 源码
│   │   ├── pages/             #     登录/MFA/主页/轮次
│   │   ├── widgets/           #     侧边栏
│   │   ├── services/          #     API 客户端 + IME 服务
│   │   ├── models/            #     数据模型
│   │   └── theme/             #     Material 3 主题
│   ├── windows/runner/        #   Windows IME 原生代码
│   ├── linux/runner/          #   Linux IME 原生代码
│   ├── macos/Runner/          #   macOS IME 原生代码
│   └── test/                  #   自动化测试
│
├── backend/                   # Go API 服务端
│   ├── internal/
│   │   ├── api/               #   HTTP handlers + 路由
│   │   ├── auth/              #   CAS 登录 / MFA / 加密 / 指纹
│   │   ├── course/            #   课程查询 / 选课提交 / 抢课引擎
│   │   ├── session/           #   全局状态 + Cookie 管理
│   │   └── config/            #   配置文件读写
│   ├── main.go
│   └── go.mod
│
├── login.py                   # 原版 PyQt5 客户端（已弃用，保留参考）
├── docs/                      # 设计文档
└── README.md
```

## 快速开始

### 1. 启动后端

```bash
cd backend
go build -o xjtu-genius .
./xjtu-genius          # 监听 127.0.0.1:18720
```

### 2. 启动前端

```bash
cd frontend
flutter run -d windows  # 或 linux / macos
```

前端自动连接 `127.0.0.1:18720` 后端。

## 功能

- **CAS 统一认证登录** — 支持 RSA 加密、验证码、MFA 二次验证、账户选择、Safety Verify
- **五类课程浏览** — 主修推荐 (TJKC) / 方案内 (FANKC) / 方案外 (FAWKC) / 通识 (XGXK) / 体育 (TYKC)
- **已选课程查看** — 含课程类型彩色标签
- **多校区支持** — 9 个校区动态切换
- **自动抢课引擎** — 并发查容量 + 串行提交 + 100ms 高频轮询 + 自动保活
- **IME 输入法自动切换** — 输入框获得焦点自动英文，离开恢复中文
- **配置持久化** — 待抢课程 + 冲突课程保存到 JSON

## 详细文档

- [后端 README](backend/README.md) — Go 后端架构、CAS 登录流程、API 文档、编译部署
- [前端 README](frontend/README.md) — Flutter 前端架构、UI 组件、IME 实现、平台适配

## 技术选型

| 层 | 技术 | 原因 |
|----|------|------|
| 前端 | Flutter 3.44+ | 跨平台桌面支持，Material 3 |
| 后端 | Go + chi + resty | 高性能 HTTP，原生并发 (goroutine) |
| 认证 | 原生 RSA + net/http Cookie Jar | 精确控制 CAS 重定向链 |
| 通信 | REST JSON | 前后端解耦，易于调试 |

## 开发

```bash
# 后端
cd backend && go build ./...

# 前端
cd frontend && dart analyze lib/ && flutter test
```
