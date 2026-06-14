# XJTU Course Genius — Go Backend

基于 Go 语言开发的西安交通大学选课系统 API 服务端，通过 CAS 统一身份认证接入 `xkfw.xjtu.edu.cn`，为 Flutter 前端提供完整的选课数据接口。

## 架构概览

```
Flutter 前端 (127.0.0.1:18720)
        │
        ▼
┌─────────────────────────────┐
│  internal/api/              │  ← chi 路由 + HTTP handlers
│    router.go   handlers.go  │
└──────────────┬──────────────┘
               │
    ┌──────────┼──────────┐
    ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌──────────┐
│  auth/ │ │course/ │ │session/  │
│ login  │ │ query  │ │ manager  │
│ mfa    │ │ round  │ │          │
│ crypto │ │select  │ │          │
│ fprint │ │        │ │          │
└───┬────┘ └───┬────┘ └──────────┘
    │          │
    ▼          ▼
┌─────────────────────────────────┐
│        xkfw.xjtu.edu.cn         │
│  (西安交通大学选课系统)           │
└─────────────────────────────────┘
```

## 目录结构

```
backend/
├── main.go                          # 入口，启动 HTTP 服务
├── go.mod / go.sum                  # Go module 依赖
├── internal/
│   ├── api/
│   │   ├── router.go                # chi 路由注册 + CORS
│   │   └── handlers.go              # 所有 API handler 实现
│   ├── auth/
│   │   ├── login.go                 # CAS 登录、重定向跟踪、注册
│   │   ├── mfa.go                   # MFA 初始化/发送/验证
│   │   ├── crypto.go                # RSA 密码加密
│   │   └── fingerprint.go           # 设备指纹生成
│   ├── course/
│   │   ├── types.go                 # 数据结构定义
│   │   ├── query.go                 # 课程查询 + 容量检查 + 选课提交
│   │   ├── round.go                 # 批次/轮次 + 校区字典
│   │   └── selection.go             # 抢课引擎（并发）
│   ├── session/
│   │   └── manager.go               # 全局状态管理 + Cookie 持久化
│   └── config/
│       └── config.go                # 配置文件读写
```

## 核心模块详解

### 1. CAS 登录 (`internal/auth/login.go`)

完整的统一身份认证流程：

```
GET xkfw.xjtu.edu.cn  →  302 重定向到 CAS
    │
    ▼
GET cas/jwt/publicKey  →  RSA 公钥
    │
    ▼
POST cas/mfa/detect    →  检测是否需要 MFA
    │
    ├── need=true  →  返回 MFA 错误，等待前端完成验证
    │
    └── need=false  →  继续
    │
    ▼
POST cas/login         →  提交加密凭据
    │  (username, __RSA__密码, execution, fpVisitorId...)
    ▼
302 → xkfw?ticket=...  →  重定向链自动跟踪
    │  (resty 自动跟随，Cookie Jar 收集 JSESSIONID)
    ▼
GET register.do?number=null  →  获取 API Token
    │  (响应: {code:"1", data:{token:"...", number:"..."}})
    ▼
登录完成，Token 存入全局状态
```

**关键函数**：

| 函数 | 作用 |
|------|------|
| `FullLoginWithCaptcha` | 完整登录入口，支持验证码 |
| `postCASRaw` | 用原生 `net/http` 提交 CAS 表单（解决 resty cookie jar 问题） |
| `followAndRegister` | 手动跟踪重定向链，提取 employeeNo，调用 register.do |
| `doRegister` | 直接调用 register.do 获取 token |
| `ReloginIfNeeded` | 抢课保活：先查 session 存活 → 失败则全量重登 |
| `IsSessionAlive` | 通过请求 dictionary.do 检查 session 是否过期 |

### 2. MFA 二次认证 (`internal/auth/mfa.go`)

```
POST /api/mfa/init   →  CAS 获取 MFA 初始化信息 (gid, attestServerUrl, target)
POST /api/mfa/send   →  向 attest 服务器发送验证码
POST /api/mfa/verify →  校验验证码 → 继续 CAS 登录流程
```

支持两种验证方式：`securephone`（短信）、`secureemail`（邮箱）。
同时处理 Safety Verify 二次安全认证流程。

### 3. 课程查询 (`internal/course/query.go`)

| 函数 | API 端点 | 说明 |
|------|----------|------|
| `GetBatches` | `student/{number}.do` | 获取可选轮次列表 |
| `EnterRound` | `student/xkxf.do` | 进入轮次，获取校区 |
| `QuerySelected` | `elective/courseResult.do` | 已选课程 |
| `QueryCourses` | `elective/{type}.do` | 按类型查询（分页自动获取全部） |
| `CheckCapacity` | `elective/teachingclass/capacity.do` | 查询课容量 |
| `Volunteer` | `elective/volunteer.do` | 提交选课 |
| `DeleteVolunteer` | `elective/deleteVolunteer.do` | 删除冲突课程 |

**课程类型映射**：

| 前端类型 | xkfw API | 数据结构 |
|----------|----------|----------|
| TJKC (主修推荐) | `recommendedCourse.do` | 嵌套 `tcList` |
| FANKC (方案内) | `programCourse.do` | 嵌套 `tcList` |
| FAWKC (方案外) | `programCourse.do` | 嵌套 `tcList` |
| XGXK (通识) | `publicCourse.do` | 嵌套 `teachingTimeList` |
| TYKC (体育) | `programCourse.do` | 嵌套 `tcList` + `sportName` |

同一课程多个教学班通过 `tcList` 数组区分，每个教学班有独立的 `teachingClassID`（末尾 `01`/`02` 区分）。

### 4. 抢课引擎 (`internal/course/selection.go`)

```
每 100ms 一轮循环：
  ┌─ 收集所有 flags[j]==0 的待抢课程
  │
  ├─ Phase 1: 并发查容量 (goroutine per course)
  │   所有课程同时 CheckCapacity()，不互相等待
  │
  ├─ Phase 2: 串行提交
  │   只对有空位的课程依次 Volunteer()
  │   (先 DeleteVolunteer 删冲突，再提交)
  │
  └─ sleep 100ms → 下一轮

每 4000 轮 (~400s) 自动 ReloginIfNeeded 保活
全部抢完自动停止
```

### 5. Session 管理 (`internal/session/manager.go`)

全局单例 `State` 持有所有运行时状态：

- `Account` / `Password` — 登录凭据
- `StudentCode` / `Token` — xkfw API 认证
- `BatchCode` / `Campus` — 当前轮次和校区
- `Cookies` — CAS/xkfw 的 Session Cookie（跨请求持久化）
- `FpVisitorID` — 设备指纹

`NewClient()` 创建 resty 客户端时自动加载已保存的 Cookie 和 Token。

### 6. 设备指纹 (`internal/auth/fingerprint.go`)

不依赖浏览器，使用系统信息生成设备指纹（SHA-256）：
- OS/Architecture
- Hostname
- CPU 核心数
- MAC 地址

## API 端点

所有端点前缀：`/api`

### 认证

| 方法 | 路径 | 请求体 | 响应 |
|------|------|--------|------|
| POST | `/login` | `{account, password, captcha?}` | `{success, studentCode, campus}` 或 `{captcha_required}` / `{mfa_required, state}` / `{account_choice_required, choices}` |
| GET | `/captcha` | — | `image/jpeg` 验证码图片 |
| POST | `/mfa/init` | `{method: "securephone"}` | `{target: "138****1234"}` |
| POST | `/mfa/send` | — | `{status: "ok"}` |
| POST | `/mfa/verify` | `{code: "123456"}` | `{success, studentCode}` |
| POST | `/account/choose` | `{accountType: "undergraduate"}` | `{success, studentCode}` |
| GET | `/session/check` | — | `{alive: true/false}` |
| POST | `/relogin` | — | `{status: "ok"}` |

### 选课数据

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/batches` | 可选轮次列表 |
| POST | `/batches/select` | `{batchCode}` 进入轮次 |
| GET | `/campus` | 校区列表 |
| POST | `/campus/set` | `{campus}` 切换校区 |
| GET | `/courses/selected` | 已选课程 |
| GET | `/courses/query/{type}` | 按类型查询 (`TJKC`/`FANKC`/`FAWKC`/`XGXK`/`TYKC`)，可选 `?keyword=` |

### 抢课

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/selection/start` | 开始抢课 |
| POST | `/selection/stop` | 停止抢课 |
| GET | `/selection/status` | `{running, totalCourse, flags, progress, log}` |

### 配置

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/config` | 读取配置 `{course, delcourses}` |
| POST | `/config` | 保存配置 `{course: [[tcId, name, teacher, place, type, campus]], delcourses: [[tcId]]}` |

### 所有 API 响应示例

**登录成功**：
```json
{
  "success": true,
  "studentCode": "2233710045",
  "campus": "1"
}
```

**需要 MFA**：
```json
{
  "mfa_required": true,
  "state": "eyJ...",
  "isSafetyVerify": false
}
```

**已选课程**：
```json
[{
  "teachingClassId": "202520262EELC32270402",
  "courseName": "模拟电子技术基础",
  "teacherName": "王振兴",
  "teachingPlace": "东1东-312",
  "classType": "96",
  "campus": "1",
  "campusName": "兴庆校区",
  "credit": "3",
  "selected": true
}]
```

**抢课状态**：
```json
{
  "running": true,
  "totalCourse": 2,
  "flags": [0, 0],
  "progress": 0,
  "log": [
    "[18:35:01] 开始抢课 — 共 2 门课程",
    "[18:35:01] [航天飞行器总体设计] 开始监控 (班号: 2025...)",
    "[18:35:01] [网络舆情监测与研判] 开始监控 (班号: 2025...)"
  ]
}
```

## 编译与部署

### 环境要求

- Go 1.21+
- 网络能访问 `xkfw.xjtu.edu.cn` 和 `login.xjtu.edu.cn`

### 编译

```bash
cd backend
go build -o xjtu-genius.exe .
```

交叉编译：
```bash
# Linux
GOOS=linux GOARCH=amd64 go build -o xjtu-genius .

# macOS
GOOS=darwin GOARCH=amd64 go build -o xjtu-genius .
```

### 运行

```bash
# 默认监听 127.0.0.1:18720
./xjtu-genius.exe

# 自定义端口
PORT=8080 ./xjtu-genius.exe
```

### 依赖

| 包 | 用途 |
|----|------|
| `github.com/go-chi/chi/v5` | HTTP 路由 |
| `github.com/go-chi/cors` | CORS 中间件 |
| `github.com/go-resty/resty/v2` | HTTP 客户端（Cookie Jar + 重试） |
| `crypto/rsa` | RSA 密码加密（标准库） |

### 安装依赖

```bash
go mod download
```

## 设计决策

### 为什么 CAS 登录用原生 net/http 而不是 resty？

resty 的 Cookie Jar 在跟随 CAS 重定向链时不正确地处理了跨域 Cookie（`login.xjtu.edu.cn` → `xkfw.xjtu.edu.cn`），导致 xkfw 的 JSESSIONID 丢失。原生 `net/http` 的 Cookie Jar 能正确处理跨域重定向中的 Cookie 设置。

### 为什么容量检查并发、选课提交串行？

- **查容量**：只读操作，无副作用，并发安全，大幅缩短每轮时间
- **提交选课**：需要先删冲突课程再提交，如果并发可能导致竞态（A 课删了 B 课的冲突，B 课又删回来）
- **100ms 间隔**：与原版 Python 登录器保持一致

### Cookie 如何在多请求间共享？

`client.GetClient()` 返回 resty 底层的 `*http.Client`，其中 `Jar` 字段持有同一个 `*cookiejar.Jar` 实例。无论是 resty 发起的请求还是原生 `http.Client.Do()` 发起的请求，都共享这个 Jar。登录完成后调用 `SaveCookiesFromHTTP` 将 Jar 中的 Cookie 持久化到全局状态，后续 `NewClient()` 自动加载。
