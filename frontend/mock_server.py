"""Mock API server for testing Flutter UI without real backend."""
import json
import time
import base64
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# In-memory state
state = {
    "session_alive": True,
    "selection_running": False,
    "selection_start_time": 0,
    "wishlist": [],
    "delcourses": [],
    "current_campus": "",
    "logs": [],
}

COURSES = {
    "TJKC": [
        {"teachingClassId": "2024AUTD113267001", "courseName": "高等数学 I-1", "teacherName": "张教授", "teachingPlace": "主楼A-301", "classType": "TJKC"},
        {"teachingClassId": "2024AUTD113267002", "courseName": "线性代数与解析几何", "teacherName": "李教授", "teachingPlace": "主楼B-201", "classType": "TJKC"},
        {"teachingClassId": "2024AUTD113267003", "courseName": "概率论与数理统计", "teacherName": "王副教授", "teachingPlace": "主楼C-102", "classType": "TJKC"},
        {"teachingClassId": "2024AUTD113267004", "courseName": "大学物理 II-1", "teacherName": "刘教授", "teachingPlace": "教二楼A-201", "classType": "TJKC"},
        {"teachingClassId": "2024AUTD113267005", "courseName": "数学物理方法", "teacherName": "陈副教授", "teachingPlace": "教一楼C-301", "classType": "TJKC"},
    ],
    "FANKC": [
        {"teachingClassId": "2024AUTN11003FAN01", "courseName": "计算机网络与通信", "teacherName": "赵教授", "teachingPlace": "电信楼A-401", "classType": "FANKC"},
        {"teachingClassId": "2024AUTN11003FAN02", "courseName": "操作系统原理", "teacherName": "钱教授", "teachingPlace": "电信楼B-301", "classType": "FANKC"},
        {"teachingClassId": "2024AUTN11003FAN03", "courseName": "数据库系统概论", "teacherName": "杨副教授", "teachingPlace": "软件楼C-202", "classType": "FANKC"},
        {"teachingClassId": "2024AUTN11003FAN04", "courseName": "软件工程导论", "teacherName": "周教授", "teachingPlace": "软件楼A-101", "classType": "FANKC"},
    ],
    "FAWKC": [
        {"teachingClassId": "2024AUTF11003FAW01", "courseName": "人工智能与机器学习", "teacherName": "孙教授", "teachingPlace": "软件楼A-201", "classType": "FAWKC"},
        {"teachingClassId": "2024AUTF11003FAW02", "courseName": "大数据分析技术", "teacherName": "周副教授", "teachingPlace": "软件楼B-101", "classType": "FAWKC"},
        {"teachingClassId": "2024AUTF11003FAW03", "courseName": "计算机视觉", "teacherName": "吴副教授", "teachingPlace": "人工智能学院A-201", "classType": "FAWKC"},
    ],
    "XGXK": [
        {"teachingClassId": "2024AUTX11003XGX01", "courseName": "中国传统文化概论", "teacherName": "吴教授", "teachingPlace": "文科楼A-101", "classType": "XGXK"},
        {"teachingClassId": "2024AUTX11003XGX02", "courseName": "西方哲学思想史", "teacherName": "郑讲师", "teachingPlace": "文科楼B-202", "classType": "XGXK"},
        {"teachingClassId": "2024AUTX11003XGX03", "courseName": "经济学原理与应用", "teacherName": "冯教授", "teachingPlace": "经管楼A-303", "classType": "XGXK"},
        {"teachingClassId": "2024AUTX11003XGX04", "courseName": "心理学与生活", "teacherName": "韩副教授", "teachingPlace": "人文楼A-102", "classType": "XGXK"},
        {"teachingClassId": "2024AUTX11003XGX05", "courseName": "法律基础与法治思维", "teacherName": "曹教授", "teachingPlace": "法学院A-201", "classType": "XGXK"},
    ],
    "TYKC": [
        {"teachingClassId": "2024AUTT11003TYK01", "courseName": "篮球（初级）", "teacherName": "陈教练", "teachingPlace": "体育馆篮球场", "classType": "TYKC"},
        {"teachingClassId": "2024AUTT11003TYK02", "courseName": "游泳（提高班）", "teacherName": "刘教练", "teachingPlace": "游泳馆", "classType": "TYKC"},
        {"teachingClassId": "2024AUTT11003TYK03", "courseName": "太极拳", "teacherName": "黄教练", "teachingPlace": "田径场", "classType": "TYKC"},
        {"teachingClassId": "2024AUTT11003TYK04", "courseName": "羽毛球", "teacherName": "林教练", "teachingPlace": "体育馆二楼", "classType": "TYKC"},
    ],
}

SELECTED_COURSES = [
    {"teachingClassId": "2024AUTD113267001", "courseName": "高等数学 I-1", "teacherName": "张教授", "teachingPlace": "主楼A-301", "classType": "TJKC", "selected": True},
    {"teachingClassId": "2024AUTN11003FAN01", "courseName": "计算机网络与通信", "teacherName": "赵教授", "teachingPlace": "电信楼A-401", "classType": "FANKC", "selected": True},
    {"teachingClassId": "2024AUTX11003XGX01", "courseName": "中国传统文化概论", "teacherName": "吴教授", "teachingPlace": "文科楼A-101", "classType": "XGXK", "selected": True},
    {"teachingClassId": "2024AUTT11003TYK01", "courseName": "篮球（初级）", "teacherName": "陈教练", "teachingPlace": "体育馆篮球场", "classType": "TYKC", "selected": True},
]

# Generate a clean captcha PNG (200x70, "A3bK" text with noise + wavy lines)
def _make_captcha():
    import struct
    import zlib
    import random
    import math

    random.seed(42)
    w, h = 200, 70

    # Simple 5x7 bitmap font
    font = {
        "A": [0b01110, 0b10001, 0b10001, 0b11111, 0b10001, 0b10001, 0b10001],
        "3": [0b01110, 0b10001, 0b00001, 0b00110, 0b00001, 0b10001, 0b01110],
        "b": [0b10000, 0b10000, 0b10110, 0b11001, 0b10001, 0b10001, 0b11110],
        "K": [0b10001, 0b10010, 0b10100, 0b11000, 0b10100, 0b10010, 0b10001],
    }

    text = "A3bK"
    pixels = set()
    char_w = 6
    total_w = len(text) * char_w
    start_x = (w - total_w) // 2
    start_y = (h - 7) // 2

    for ci, ch in enumerate(text):
        if ch in font:
            for row in range(7):
                bits = font[ch][row]
                for col in range(5):
                    if bits & (1 << (4 - col)):
                        pixels.add((start_x + ci * char_w + col, start_y + row))

    raw = b""
    for y in range(h):
        raw += b"\x00"
        for x in range(w):
            r, g, b = 255, 255, 255
            a = 255

            # Subtle noise dots
            if random.random() < 0.025:
                v = random.randint(195, 230)
                r, g, b = v, v, v

            # Wavy distortion lines
            if (x + int(4 * math.sin(y * 0.25))) % 28 < 1:
                r, g, b = 212, 220, 232

            # Text pixels (dark)
            if (x, y) in pixels:
                r, g, b = 45, 45, 45

            raw += struct.pack("BBBB", r, g, b, a)

    sig = b"\x89PNG\r\n\x1a\n"

    def _chunk(ct, data):
        c = ct + data
        return (
            struct.pack(">I", len(data))
            + c
            + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
        )

    return (
        sig
        + _chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + _chunk(b"IDAT", zlib.compress(raw))
        + _chunk(b"IEND", b"")
    )


CAPTCHA_PNG = _make_captcha()


class MockHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # suppress logs

    def _send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_png(self, data):
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return {}
        return json.loads(self.rfile.read(length))

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        # Captcha image
        if path == "/api/captcha":
            return self._send_png(CAPTCHA_PNG)

        # Session check
        if path == "/api/session/check":
            return self._send_json({"alive": state["session_alive"]})

        # Batches list
        if path == "/api/batches":
            return self._send_json([
                {"code": "batch_2025_1", "name": "第一轮选课 (2025春)", "canSelect": "1"},
                {"code": "batch_2025_2", "name": "第二轮选课 (2025春)", "canSelect": "1"},
                {"code": "batch_2024_3", "name": "第三轮选课 (2024秋·已结束)", "canSelect": "0"},
            ])

        # Campus list
        if path == "/api/campus":
            return self._send_json([
                {"code": "xq", "name": "兴庆校区"},
                {"code": "cx", "name": "创新港校区"},
                {"code": "yt", "name": "雁塔校区"},
            ])

        # Selected courses
        if path == "/api/courses/selected":
            return self._send_json(SELECTED_COURSES)

        # Course query by type: /api/courses/query/{type}
        if path.startswith("/api/courses/query/"):
            course_type = path.split("/")[-1].upper()
            if course_type == "ALL":
                courses = []
                for c_list in COURSES.values():
                    courses.extend(c_list)
            else:
                courses = COURSES.get(course_type, [])
            qs = parse_qs(parsed.query)
            keyword = qs.get("keyword", [""])[0].lower()
            if keyword:
                courses = [c for c in courses
                           if keyword in c["courseName"].lower()
                           or keyword in c["teacherName"].lower()]
            return self._send_json({"courses": courses})

        # Config
        if path == "/api/config":
            return self._send_json({
                "course": state["wishlist"],
                "delcourses": state["delcourses"],
            })

        # Selection status
        if path == "/api/selection/status":
            elapsed = int(time.time() - state["selection_start_time"]) if state["selection_start_time"] else 0
            total = len(state["wishlist"])
            done = min(elapsed, total)
            still_running = state["selection_running"] and done < total
            flags = [1 if i < done else 0 for i in range(total)]
            return self._send_json({
                "running": still_running,
                "totalCourse": total,
                "flags": flags,
                "progress": done,
                "log": [
                    "[10:30:01] 开始抢课",
                    *[f"[10:30:{2+i:02d}] 课程{i+1}/{total} — {'抢课成功 ✓' if i < done else '正在抢课...' if i == done else '等待中'}"
                      for i in range(total)],
                    f"[10:30:{total+2:02d}] {'本轮抢课已完成 ✓' if done >= total else '仍在抢课中...'}",
                ],
            })

        self._send_json({"error": f"GET {path} not found"}, 404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        body = self._read_body()

        # Login: special accounts trigger different flows
        if path == "/api/login":
            account = body.get("account", "")
            captcha = body.get("captcha", "")
            pwd = body.get("password", "")

            # Trigger captcha flow
            if account == "captcha" and not captcha:
                return self._send_json({
                    "success": False,
                    "captcha_required": True,
                    "mfa_required": False,
                    "account_choice_required": False,
                })

            # Trigger account choice flow
            if account == "choice":
                return self._send_json({
                    "success": False,
                    "captcha_required": False,
                    "mfa_required": False,
                    "account_choice_required": True,
                    "choices": [
                        {"name": "本科 2019级"},
                        {"name": "研究生 2024级"},
                    ],
                })

            # Trigger MFA flow
            if account == "mfa":
                return self._send_json({
                    "success": False,
                    "captcha_required": False,
                    "mfa_required": True,
                    "account_choice_required": False,
                })

            # Login error
            if account == "error":
                return self._send_json({
                    "success": False,
                    "error": "账号或密码错误，请重新输入",
                    "captcha_required": False,
                    "mfa_required": False,
                    "account_choice_required": False,
                })

            # Default: direct success
            return self._send_json({
                "success": True,
                "captcha_required": False,
                "mfa_required": False,
                "account_choice_required": False,
                "campus": "xq",
            })

        # MFA init
        if path == "/api/mfa/init":
            method = body.get("method", "securephone")
            target = "138****1234" if method == "securephone" else "stu***@xjtu.edu.cn"
            return self._send_json({"success": True, "target": target})

        # MFA send
        if path == "/api/mfa/send":
            return self._send_json({"success": True})

        # MFA verify
        if path == "/api/mfa/verify":
            code = body.get("code", "")
            if code == "123456":
                return self._send_json({"success": True})
            return self._send_json({"error": "验证码错误"}, 400)

        # Account choice
        if path == "/api/account/choose":
            return self._send_json({"success": True, "campus": "yt"})

        # Enter round
        if path == "/api/batches/select":
            return self._send_json({"success": True})

        # Set campus
        if path == "/api/campus/set":
            state["current_campus"] = body.get("campus", "")
            return self._send_json({"success": True})

        # Save config
        if path == "/api/config":
            state["wishlist"] = body.get("course", [])
            state["delcourses"] = body.get("delcourses", [])
            print(f"[Mock] Config saved: {len(state['wishlist'])} courses")
            return self._send_json({"success": True})

        # Start selection
        if path == "/api/selection/start":
            state["selection_running"] = True
            state["selection_start_time"] = time.time()
            return self._send_json({"success": True})

        # Stop selection
        if path == "/api/selection/stop":
            state["selection_running"] = False
            return self._send_json({"success": True})

        # Relogin
        if path == "/api/relogin":
            state["session_alive"] = True
            return self._send_json({"success": True})

        self._send_json({"error": f"POST {path} not found"}, 404)


def main():
    server = HTTPServer(("127.0.0.1", 18720), MockHandler)
    print("Mock API server running at http://127.0.0.1:18720")
    print("Endpoints ready for full UI testing:")
    print("  POST /api/login           → success (skip captcha/MFA)")
    print("  GET  /api/batches          → 3 rounds")
    print("  POST /api/batches/select   → success")
    print("  GET  /api/courses/query/*  → mock courses")
    print("  GET  /api/courses/selected → mock selected")
    print("  GET  /api/config           → wishlist + delcourses")
    print("  POST /api/config           → save")
    print("  POST /api/selection/start  → start grabbing")
    print("  GET  /api/selection/status → progress + logs")
    print("  POST /api/selection/stop   → stop")
    print("  GET  /api/campus           → 3 campuses")
    print("  POST /api/campus/set       → set campus")
    print("\nPress Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
        server.shutdown()


if __name__ == "__main__":
    main()
