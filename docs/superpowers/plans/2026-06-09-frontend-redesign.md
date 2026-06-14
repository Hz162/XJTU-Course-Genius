# Frontend Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign XJTU Course Genius Flutter frontend with sidebar navigation, Noto Sans SC typography, polished login/MFA pages, and keyboard shortcuts.

**Architecture:** Sidebar-based desktop layout with `Sidebar` widget driving panel switching in `HomePage`. All 6 course types plus selection/config in sidebar groups. Theme updated with gradient buttons and card shadows. `ShortcutManager` mixin/helper for keyboard bindings.

**Tech Stack:** Flutter 3.44+, Dart 3.12+, Material 3, Noto Sans SC font, window_manager

**Files created:** `lib/widgets/sidebar.dart`, `lib/services/shortcut_manager.dart`
**Files rewritten:** `lib/pages/login_page.dart`, `lib/pages/mfa_page.dart`, `lib/pages/home_page.dart`
**Files modified:** `lib/theme/app_theme.dart`, `lib/pages/round_page.dart`, `pubspec.yaml`
**Assets added:** `assets/logo.png`, `assets/fonts/NotoSansSC-Regular.ttf`, `assets/fonts/NotoSansSC-Bold.ttf`

---

### Task 1: Setup assets and font

**Files:**
- Create: `assets/fonts/` directory
- Modify: `pubspec.yaml`

- [ ] **Step 1: Download Noto Sans SC font files**

Download from Google Fonts and place in `assets/fonts/`:
- `NotoSansSC-Regular.ttf` → `assets/fonts/`
- `NotoSansSC-Bold.ttf` → `assets/fonts/`

```powershell
$fontsDir = "D:\XJTU-Course-Genius\frontend\assets\fonts"
New-Item -ItemType Directory -Force -Path $fontsDir
Invoke-WebRequest -Uri "https://github.com/google/fonts/raw/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf" -OutFile "$fontsDir\NotoSansSC-Regular.ttf"
```

(If download fails, use Noto Sans SC from any available source; the variable font covers all weights.)

- [ ] **Step 2: Create placeholder logo**

Generate a simple blue square PNG as default logo:

```powershell
$assetsDir = "D:\XJTU-Course-Genius\frontend\assets"
New-Item -ItemType Directory -Force -Path $assetsDir
# Use flutter to generate a simple logo or create a 1x1 pixel placeholder
# For now, create an empty file marker — logo.png will be replaced by user
"" | Set-Content "$assetsDir\logo.png"
```

- [ ] **Step 3: Update pubspec.yaml**

Add font family and asset declarations. Read current `pubspec.yaml` and replace the `flutter:` section:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/logo.png
  fonts:
    - family: NotoSansSC
      fonts:
        - asset: assets/fonts/NotoSansSC-Regular.ttf
          weight: 400
        - asset: assets/fonts/NotoSansSC-Bold.ttf
          weight: 700
```

Use Edit tool: replace `flutter:\n  uses-material-design: true` with the block above.

- [ ] **Step 4: Run flutter pub get**

```powershell
cd D:\XJTU-Course-Genius\frontend; flutter pub get
```

Expected: dependencies resolve without error.

- [ ] **Step 5: Commit**

```bash
git add assets/ pubspec.yaml
git commit -m "feat: add Noto Sans SC font and logo asset"
```

---

### Task 2: Update theme

**Files:**
- Modify: `lib/theme/app_theme.dart`

- [ ] **Step 1: Rewrite app_theme.dart**

Replace entire file content:

```dart
import 'package:flutter/material.dart';

const primaryColor = Color(0xFF409EFF);
const primaryLight = Color(0xFF66B1FF);
const bgColor = Color(0xFFF5F7FA);

const cardBorderRadius = 12.0;
const inputBorderRadius = 8.0;

const Gradient primaryGradient = LinearGradient(
  colors: [primaryColor, primaryLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

ThemeData appTheme() => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primaryColor,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgColor,
      fontFamily: 'NotoSansSC',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF303133),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardBorderRadius)),
        color: Colors.white,
        shadowColor: Colors.black12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: Color(0xFFDCDFE6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: Color(0xFFDCDFE6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(inputBorderRadius)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(inputBorderRadius)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(inputBorderRadius)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
    );
```

- [ ] **Step 2: Build and verify**

```powershell
cd D:\XJTU-Course-Genius\frontend; flutter build windows
```

Expected: build succeeds (font will be applied; pre-existing pages still compile).

- [ ] **Step 3: Commit**

```bash
git add lib/theme/app_theme.dart
git commit -m "feat: update theme with Noto Sans SC, gradient, card shadows"
```

---

### Task 3: Sidebar widget

**Files:**
- Create: `lib/widgets/sidebar.dart`

- [ ] **Step 1: Create sidebar widget**

```dart
import 'package:flutter/material.dart';

enum SidebarItem {
  selected,
  tjkc,
  fankc,
  fawkc,
  xgxk,
  tykc,
  selection,
  config,
}

class Sidebar extends StatefulWidget {
  final SidebarItem selected;
  final String campus;
  final List<DropdownMenuItem<String>> campusItems;
  final ValueChanged<SidebarItem> onItemSelected;
  final ValueChanged<String> onCampusChanged;
  final bool collapsed;

  const Sidebar({
    super.key,
    required this.selected,
    required this.campus,
    required this.campusItems,
    required this.onItemSelected,
    required this.onCampusChanged,
    this.collapsed = false,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.collapsed ? 0 : 200,
      color: Colors.white,
      child: Column(
        children: [
          _buildSection('课程浏览', [
            _item(SidebarItem.selected, '已选课程', Icons.list_alt),
            _item(SidebarItem.tjkc, '主修推荐', Icons.star_outline),
            _item(SidebarItem.fankc, '方案内', Icons.swap_horiz),
            _item(SidebarItem.fawkc, '方案外', Icons.open_in_new),
            _item(SidebarItem.xgxk, '基础通识', Icons.public),
            _item(SidebarItem.tykc, '体育', Icons.sports_soccer),
          ]),
          const Divider(height: 1),
          _buildSection('操作', [
            _item(SidebarItem.selection, '选课控制', Icons.play_circle_outline),
            _item(SidebarItem.config, '配置管理', Icons.settings),
          ]),
          const Spacer(),
          _buildCampusSelector(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(title, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: Color(0xFF909399), letterSpacing: 1,
            )),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _item(SidebarItem item, String label, IconData icon) {
    final active = widget.selected == item;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: active ? const Color(0xFFECF5FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onItemSelected(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: active
                    ? const Color(0xFF409EFF) : const Color(0xFF909399)),
                const SizedBox(width: 10),
                Text(label, style: TextStyle(
                  fontSize: 13,
                  color: active ? const Color(0xFF409EFF) : const Color(0xFF606266),
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampusSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Color(0xFF909399)),
            const SizedBox(width: 8),
            const Text('校区', style: TextStyle(fontSize: 12, color: Color(0xFF909399))),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.campus.isNotEmpty ? widget.campus : null,
                  isExpanded: true,
                  isDense: true,
                  hint: const Text('选择', style: TextStyle(fontSize: 12)),
                  items: widget.campusItems,
                  onChanged: (v) {
                    if (v != null) widget.onCampusChanged(v);
                  },
                  style: const TextStyle(fontSize: 12, color: Color(0xFF303133)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

```powershell
cd D:\XJTU-Course-Genius\frontend; flutter build windows
```

Expected: widget compiles but not yet used anywhere (no-op compile check).

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/sidebar.dart
git commit -m "feat: add sidebar navigation widget"
```

---

### Task 4: Rewrite login page

**Files:**
- Rewrite: `lib/pages/login_page.dart`

- [ ] **Step 1: Write new login_page.dart**

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'round_page.dart';
import 'mfa_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _accountCtl = TextEditingController();
  final _pwdCtl = TextEditingController();
  final _captchaCtl = TextEditingController();
  final _focusNode = FocusNode();
  final _api = ApiService();
  bool _loading = false;
  bool _captchaRequired = false;
  Uint8List? _captchaImg;

  @override
  void dispose() {
    _accountCtl.dispose();
    _pwdCtl.dispose();
    _captchaCtl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    try {
      final bytes = await _api.getCaptchaImage();
      if (mounted) setState(() => _captchaImg = Uint8List.fromList(bytes));
    } catch (_) {}
  }

  Future<void> _login() async {
    final account = _accountCtl.text.trim();
    final pwd = _pwdCtl.text.trim();
    if (account.isEmpty || pwd.isEmpty) {
      _showError('账号和密码不能为空');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await _api.login(account, pwd,
          captcha: _captchaRequired ? _captchaCtl.text.trim() : '');

      if (result['captcha_required'] == true) {
        setState(() { _captchaRequired = true; _loading = false; });
        _loadCaptcha();
        return;
      }

      if (result['account_choice_required'] == true) {
        final choices = List<Map<String, String>>.from(result['choices'] ?? []);
        if (!mounted) return;
        setState(() => _loading = false);
        final chosen = await _showAccountChoice(choices);
        if (chosen == null) return;
        setState(() => _loading = true);
        final choiceResult = await _api.chooseAccount(chosen);
        if (choiceResult['success'] == true) {
          _gotoRounds();
        } else {
          _showError(choiceResult['error'] ?? '账户选择失败');
        }
        return;
      }

      if (result['mfa_required'] == true) {
        if (!mounted) return;
        final ok = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => MfaPage(api: _api)),
        );
        if (ok == true) _gotoRounds();
      } else if (result['success'] == true) {
        _gotoRounds();
      } else {
        _showError(result['error'] ?? '登录失败');
      }
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _gotoRounds() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RoundPage(api: _api)),
    );
  }

  Future<String?> _showAccountChoice(List<Map<String, String>> choices) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择登录身份'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: choices.map((c) => ListTile(
            title: Text(c['name'] ?? ''),
            onTap: () {
              final type = (c['name'] ?? '').contains('本科')
                  ? 'undergraduate' : 'postgraduate';
              Navigator.pop(ctx, type);
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        HardwareKeyboard.instance.isControlPressed) {
      _login();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Focus(
        onKeyEvent: _handleKey,
        child: Center(
          child: _loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 40, height: 40,
                        child: CircularProgressIndicator(strokeWidth: 3)),
                    SizedBox(height: 16),
                    Text('正在登录...', style: TextStyle(color: Color(0xFF909399))),
                  ],
                )
              : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 24, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogo(),
          const SizedBox(height: 12),
          const Text('西安交通大学', style: TextStyle(
            fontSize: 13, color: Color(0xFF909399))),
          const SizedBox(height: 4),
          const Text('统一身份认证', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF303133))),
          const SizedBox(height: 28),
          _buildInputs(),
          if (_captchaRequired) ...[
            const SizedBox(height: 12),
            _buildCaptcha(),
          ],
          const SizedBox(height: 24),
          _buildLoginButton(),
          const SizedBox(height: 12),
          const Text('Ctrl + Enter 快速登录', style: TextStyle(
            fontSize: 11, color: Color(0xFFC0C4CC))),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 56, height: 56,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        gradient: primaryGradient,
      ),
      child: Center(
        child: Image.asset('assets/logo.png',
            width: 56, height: 56,
            errorBuilder: (_, __, ___) => const Text('西',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700))),
      ),
    );
  }

  Widget _buildInputs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        children: [
          TextField(
            controller: _accountCtl,
            decoration: const InputDecoration(
              hintText: '请输入账号',
              prefixIcon: Icon(Icons.person_outline, color: Color(0xFFC0C4CC)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFEBEEF5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFEBEEF5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          Container(height: 1, color: const Color(0xFFF2F6FC)),
          TextField(
            controller: _pwdCtl,
            decoration: const InputDecoration(
              hintText: '请输入密码',
              prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFC0C4CC)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFEBEEF5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFEBEEF5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptcha() {
    return Column(
      children: [
        if (_captchaImg != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: _loadCaptcha,
              child: Image.memory(_captchaImg!, height: 44),
            ),
          )
        else
          const CircularProgressIndicator(strokeWidth: 2),
        const SizedBox(height: 8),
        TextField(
          controller: _captchaCtl,
          decoration: const InputDecoration(
            hintText: '输入验证码',
            prefixIcon: Icon(Icons.security, color: Color(0xFFC0C4CC)),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity, height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: _loading ? null : primaryGradient,
          boxShadow: _loading ? null : const [
            BoxShadow(color: Color(0x4D409EFF), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: FilledButton(
          onPressed: _loading ? null : _login,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('登 录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Build and verify**

```powershell
cd D:\XJTU-Course-Genius\frontend; flutter build windows
```

Expected: build succeeds. Login page renders with new design.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/login_page.dart
git commit -m "feat: redesign login page with gradient card, logo, keyboard shortcut"
```

---

### Task 5: Rewrite MFA page

**Files:**
- Rewrite: `lib/pages/mfa_page.dart`

- [ ] **Step 1: Write new mfa_page.dart**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MfaPage extends StatefulWidget {
  final ApiService api;
  const MfaPage({super.key, required this.api});

  @override
  State<MfaPage> createState() => _MfaPageState();
}

class _MfaPageState extends State<MfaPage> {
  String _method = 'securephone';
  String _target = '';
  final _codeCtl = TextEditingController();
  bool _initDone = false;
  bool _sending = false;
  int _countdown = 0;
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _autoInit();
  }

  @override
  void dispose() {
    _codeCtl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _autoInit() async {
    try {
      final result = await widget.api.mfaInit(_method);
      if (!mounted) return;
      setState(() {
        _target = result['target'] ?? '';
        _initDone = true;
        _loading = false;
      });
      _sendCode();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('MFA初始化失败');
    }
  }

  Future<void> _sendCode() async {
    setState(() => _sending = true);
    try {
      await widget.api.mfaSend();
      _startCountdown();
    } catch (e) {
      _showError('发送失败');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 1) { _countdown--; }
        else { _countdown = 0; t.cancel(); }
      });
    });
  }

  Future<void> _verify() async {
    final code = _codeCtl.text.trim();
    if (code.isEmpty) {
      _showError('请输入验证码');
      return;
    }
    try {
      await widget.api.mfaVerify(code);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('验证码错误');
    }
  }

  Future<void> _switchMethod(String m) async {
    setState(() { _method = m; _initDone = false; _loading = true; });
    await _autoInit();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(title: const Text('二次认证')),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 24, offset: Offset(0, 4)),
            ],
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStepRow(1, '选择验证方式'),
                    const SizedBox(height: 12),
                    _buildMethodCards(),
                    const SizedBox(height: 24),
                    _buildStepRow(2, _target.isNotEmpty
                        ? '验证码已发送至 ${_obscureTarget(_target)}'
                        : '输入验证码'),
                    const SizedBox(height: 12),
                    _buildCodeInput(),
                    const SizedBox(height: 20),
                    _buildVerifyButton(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStepRow(int step, String label) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: primaryGradient,
          ),
          child: Center(child: Text('$step',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF303133))),
      ],
    );
  }

  Widget _buildMethodCards() {
    return Row(
      children: [
        _methodCard('securephone', '手机短信', Icons.phone_android),
        const SizedBox(width: 12),
        _methodCard('secureemail', '邮箱验证', Icons.email_outlined),
      ],
    );
  }

  Widget _methodCard(String value, String label, IconData icon) {
    final selected = _method == value;
    return Expanded(
      child: GestureDetector(
        onTap: selected ? null : () => _switchMethod(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFECF5FF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? primaryColor : const Color(0xFFEBEEF5),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? primaryColor : const Color(0xFF909399), size: 22),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: selected ? primaryColor : const Color(0xFF606266),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeInput() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _codeCtl,
            decoration: const InputDecoration(
              hintText: '输入验证码',
              prefixIcon: Icon(Icons.pin_outlined, color: Color(0xFFC0C4CC)),
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _verify(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: OutlinedButton(
            onPressed: (_countdown == 0 && !_sending) ? _sendCode : null,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(
              _countdown > 0 ? '${_countdown}s' : '重新发送',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: primaryGradient,
          boxShadow: const [
            BoxShadow(color: Color(0x4D409EFF), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: FilledButton(
          onPressed: _verify,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('验 证', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  String _obscureTarget(String target) {
    if (target.length <= 4) return target;
    final half = (target.length - 4) ~/ 2;
    return '${target.substring(0, half)}****${target.substring(target.length - (4 - half))}';
  }
}
```

- [ ] **Step 2: Build and verify**

```powershell
cd D:\XJTU-Course-Genius\frontend; flutter build windows
```

Expected: build succeeds. MFA page renders with step indicators and card selectors.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/mfa_page.dart
git commit -m "feat: redesign MFA page with step flow, card method picker, auto-init"
```

---

### Task 6: Update round page

**Files:**
- Modify: `lib/pages/round_page.dart`

- [ ] **Step 1: Enhance round page UI**

Read current `round_page.dart`, add batch description display and polish. Replace `build` method:

The key change: add subtitle text showing the selected batch's info before the confirm button.

```dart
// In build(), after the DropdownButtonFormField, add:
const SizedBox(height: 16),
if (_batches.isNotEmpty && _selectedIndex < _batches.length)
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFECF5FF),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _batches[_selectedIndex].canSelect == '0'
                ? '当前不在选课开放时间内'
                : '可选中，点击确定进入',
            style: const TextStyle(fontSize: 12, color: Color(0xFF409EFF)),
          ),
        ),
      ],
    ),
  ),
```

Also wrap the whole Column in a white card with shadow, similar to login/mfa pages. Use `Container` with `BoxDecoration` (borderRadius 16, boxShadow, white background).

- [ ] **Step 2: Build and verify**

```powershell
cd D:\XJTU-Course-Genius\frontend; flutter build windows
```

- [ ] **Step 3: Commit**

```bash
git add lib/pages/round_page.dart
git commit -m "feat: add batch info hint and card styling to round page"
```

---

### Task 7: Rewrite home page with sidebar

**Files:**
- Rewrite: `lib/pages/home_page.dart`

This is the largest task. The new home page uses sidebar + 3 panels (course browsing, selection control, config management).

- [ ] **Step 1: Write new home_page.dart**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/course.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';

class HomePage extends StatefulWidget {
  final ApiService api;
  const HomePage({super.key, required this.api});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ApiService api;

  // currently active sidebar item
  SidebarItem _currentItem = SidebarItem.selected;
  String _currentView = 'selected'; // for course query types
  String _keyword = '';
  final _keywordCtl = TextEditingController();
  bool _loading = false;
  List<dynamic> _tableData = [];

  // Campus
  List<dynamic> _campusList = [];
  String _currentCampus = '';

  // Wish list & config
  List<List<String>> _wishList = [];
  List<List<String>> _delCourses = [];

  // Selection state
  SelectionStatus? _selStatus;
  Timer? _statusTimer;
  bool _selecting = false;

  // Sidebar collapse
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    api = widget.api;
    _loadConfig();
    _loadCampus();
  }

  @override
  void dispose() {
    _keywordCtl.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  // ─── Data loading ───

  Future<void> _loadConfig() async {
    try {
      final cfg = await api.getConfig();
      setState(() {
        _wishList = List<List<String>>.from(
            (cfg['course'] as List?)?.map((e) => List<String>.from(e)) ?? []);
        _delCourses = List<List<String>>.from(
            (cfg['delcourses'] as List?)?.map((e) => List<String>.from(e)) ?? []);
      });
    } catch (_) {}
  }

  Future<void> _saveConfig() async {
    await api.saveConfig(_wishList, _delCourses);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _loadCampus() async {
    try {
      final list = await api.getCampusList();
      if (mounted) setState(() => _campusList = list);
    } catch (_) {}
  }

  Future<void> _loadCourseData(String view) async {
    setState(() => _loading = true);
    try {
      List<dynamic> data;
      if (view == 'selected') {
        data = await api.getSelectedCourses();
      } else {
        final result = await api.queryCourses(view, keyword: _keyword);
        data = (result['courses'] as List?) ?? [];
      }
      if (!mounted) return;
      setState(() { _tableData = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ─── Actions ───

  Future<void> _addToWishList(Map<String, dynamic> item) async {
    final entry = [
      (item['teachingClassId'] ?? '').toString(),
      (item['courseName'] ?? '').toString(),
      (item['teacherName'] ?? '').toString(),
      (item['teachingPlace'] ?? '').toString(),
      (item['classType'] ?? _currentView).toString(),
      _currentCampus,
    ];
    if (_wishList.any((e) => e.isNotEmpty && e[0] == entry[0])) {
      _showError('已在抢课列表中');
      return;
    }
    setState(() {
      _wishList.add(entry);
      _delCourses.add([]);
    });
    await _saveConfig();
  }

  Future<void> _removeWishItem(int idx) async {
    setState(() {
      _wishList.removeAt(idx);
      _delCourses.removeAt(idx);
    });
    await _saveConfig();
  }

  Future<void> _addConflictCourse(int wishIdx, String courseId) async {
    if (courseId.isEmpty || wishIdx >= _delCourses.length) return;
    setState(() {
      _delCourses[wishIdx].add(courseId);
      _delCourses[wishIdx] = _delCourses[wishIdx].toSet().toList();
    });
    await _saveConfig();
  }

  Future<void> _removeConflictCourse(int wishIdx, String courseId) async {
    if (wishIdx >= _delCourses.length) return;
    setState(() => _delCourses[wishIdx].remove(courseId));
    await _saveConfig();
  }

  Future<void> _toggleSelection() async {
    if (_selecting) {
      await api.stopSelection();
      _statusTimer?.cancel();
      setState(() => _selecting = false);
    } else {
      await api.startSelection();
      setState(() => _selecting = true);
      _pollStatus();
    }
  }

  void _pollStatus() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final s = await api.getSelectionStatus();
        if (!mounted) return;
        setState(() {
          _selStatus = s;
          if (!s.running) { _selecting = false; _statusTimer?.cancel(); }
        });
      } catch (_) {}
    });
  }

  Future<void> _setCampus(String code) async {
    _currentCampus = code;
    await api.setCampus(code);
    if (mounted) setState(() {});
    _loadCourseData(_currentView);
  }

  void _onSidebarItem(SidebarItem item) {
    setState(() => _currentItem = item);
    switch (item) {
      case SidebarItem.selected: _currentView = 'selected'; break;
      case SidebarItem.tjkc: _currentView = 'TJKC'; break;
      case SidebarItem.fankc: _currentView = 'FANKC'; break;
      case SidebarItem.fawkc: _currentView = 'FAWKC'; break;
      case SidebarItem.xgxk: _currentView = 'XGXK'; break;
      case SidebarItem.tykc: _currentView = 'TYKC'; break;
      case SidebarItem.selection: case SidebarItem.config: break;
    }
    if (item != SidebarItem.selection && item != SidebarItem.config) {
      _loadCourseData(_currentView);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400),
    );
  }

  // ─── Keyboard shortcuts ───

  KeyEventResult _handleGlobalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed;

    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyB) {
      _toggleSelection();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyS) {
      _saveConfig();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f5) {
      if (_currentItem != SidebarItem.selection && _currentItem != SidebarItem.config) {
        _loadCourseData(_currentView);
      }
      return KeyEventResult.handled;
    }
    if (ctrl) {
      final digits = {
        LogicalKeyboardKey.digit1: SidebarItem.selected,
        LogicalKeyboardKey.digit2: SidebarItem.tjkc,
        LogicalKeyboardKey.digit3: SidebarItem.fankc,
        LogicalKeyboardKey.digit4: SidebarItem.fawkc,
        LogicalKeyboardKey.digit5: SidebarItem.xgxk,
        LogicalKeyboardKey.digit6: SidebarItem.tykc,
      };
      if (digits.containsKey(event.logicalKey)) {
        _onSidebarItem(digits[event.logicalKey]!);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleGlobalKey,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text('XJTU Course Genius'),
          leading: IconButton(
            icon: Icon(_sidebarCollapsed ? Icons.menu : Icons.menu_open),
            onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          ),
          actions: [
            if (_selecting)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: const SizedBox(
                      width: 10, height: 10,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  label: const Text('抢课中', style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.green.shade500,
                ),
              ),
          ],
        ),
        body: Row(
          children: [
            Sidebar(
              selected: _currentItem,
              campus: _currentCampus,
              collapsed: _sidebarCollapsed,
              campusItems: _campusList.map<DropdownMenuItem<String>>((c) {
                return DropdownMenuItem<String>(
                  value: c['code']?.toString() ?? '',
                  child: Text(c['name']?.toString() ?? ''),
                );
              }).toList(),
              onItemSelected: _onSidebarItem,
              onCampusChanged: _setCampus,
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentItem) {
      case SidebarItem.selection: return _buildSelectionPanel();
      case SidebarItem.config: return _buildConfigPanel();
      default: return _buildCoursePanel();
    }
  }

  // ─── Panel: Course Browser ───

  Widget _buildCoursePanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          Expanded(child: _buildCourseTable()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    if (_currentView == 'selected') return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _keywordCtl,
            decoration: const InputDecoration(hintText: '搜索课程名称或教师...'),
            onChanged: (v) => _keyword = v,
            onSubmitted: (_) => _loadCourseData(_currentView),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: () => _loadCourseData(_currentView), child: const Text('搜索')),
      ],
    );
  }

  Widget _buildCourseTable() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tableData.isEmpty) return const Center(child: Text('暂无数据', style: TextStyle(color: Color(0xFF909399))));
    return ListView.builder(
      itemCount: _tableData.length,
      itemBuilder: (_, i) {
        final item = _tableData[i];
        final id = (item['teachingClassId'] ?? '').toString();
        final inWish = _wishList.any((e) => e.isNotEmpty && e[0] == id);
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            title: Text((item['courseName'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              '${(item['teacherName'] ?? '').toString()} · ${(item['teachingPlace'] ?? '').toString()}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF909399)),
            ),
            leading: Text(id, style: const TextStyle(fontSize: 11, color: Color(0xFFC0C4CC))),
            trailing: _currentView == 'selected'
                ? Text(item['selected'] == true ? '✓' : '×',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: item['selected'] == true ? Colors.green : Colors.red))
                : inWish
                    ? const Text('已添加', style: TextStyle(fontSize: 11, color: Color(0xFF67C23A)))
                    : TextButton(
                        onPressed: () => _addToWishList(item),
                        child: const Text('+ 抢课', style: TextStyle(fontSize: 12, color: Color(0xFF409EFF))),
                      ),
          ),
        );
      },
    );
  }

  // ─── Panel: Selection Control ───

  Widget _buildSelectionPanel() {
    final s = _selStatus;
    final doneCount = s?.flags.where((f) => f == 1).length ?? 0;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(_selecting ? Icons.sync : Icons.play_circle_outline,
                      size: 64, color: _selecting ? Colors.green : primaryColor),
                  const SizedBox(height: 16),
                  Text(_selecting ? '抢课进行中...' : '准备就绪',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 24),
                  if (s != null) ...[
                    LinearProgressIndicator(
                      value: s.totalCourse > 0 ? s.progress / s.totalCourse : 0,
                      minHeight: 8, borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 12),
                    Text('进度 $doneCount / ${s.totalCourse}  ·  已抢到 $doneCount 门',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF909399))),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200, height: 56,
                    child: FloatingActionButton.extended(
                      onPressed: _toggleSelection,
                      backgroundColor: _selecting ? Colors.red.shade400 : primaryColor,
                      icon: Icon(_selecting ? Icons.stop : Icons.play_arrow, size: 28),
                      label: Text(_selecting ? '停 止' : '开 始',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_wishList.isNotEmpty && _selecting) ...[
            const SizedBox(height: 16),
            Text('待抢课程 (${_wishList.length} 门)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _wishList.length,
                itemBuilder: (_, i) {
                  final c = _wishList[i];
                  final done = s != null && i < s.flags.length && s.flags[i] == 1;
                  return ListTile(
                    leading: Icon(done ? Icons.check_circle : Icons.pending,
                        color: done ? Colors.green : Colors.orange),
                    title: Text(c.length > 1 ? c[1] : c[0]),
                    subtitle: Text(c.isNotEmpty ? c[0] : ''),
                    trailing: done ? null : const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
              ),
            ),
          ],
          if (s != null && s.log.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('日志', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: s.log.length,
                  itemBuilder: (_, i) => Text(s.log[i],
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Panel: Config ───

  Widget _buildConfigPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('抢课列表', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _loadConfig,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('读取'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saveConfig,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('保存'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_wishList.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('暂无课程\n在课程浏览页面点击"+抢课"添加',
                    textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF909399)))),
              ),
            )
          else Expanded(
            child: ListView.builder(
              itemCount: _wishList.length,
              itemBuilder: (_, i) {
                final c = _wishList[i];
                final conflicts = i < _delCourses.length ? _delCourses[i] : <String>[];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: Text(c.isNotEmpty ? c[0] : '?',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                    title: Text(c.length > 1 ? c[1] : '?', style: const TextStyle(fontSize: 14)),
                    subtitle: Text('${c.length > 3 ? c[3] : ''} · 冲突: ${conflicts.length}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF909399))),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _removeWishItem(i),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (conflicts.isNotEmpty) ...[
                              const Text('冲突课程:', style: TextStyle(fontSize: 11, color: Color(0xFF909399))),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6, runSpacing: 4,
                                children: conflicts.map((id) => Chip(
                                  label: Text(id, style: const TextStyle(fontSize: 11)),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () => _removeConflictCourse(i, id),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                )).toList(),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      hintText: '课程班号', isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                    onSubmitted: (v) { _addConflictCourse(i, v); },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    final ctl = TextEditingController();
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('添加冲突课程'),
                                        content: TextField(controller: ctl, autofocus: true,
                                            decoration: const InputDecoration(hintText: '课程班号')),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                                          FilledButton(onPressed: () {
                                            _addConflictCourse(i, ctl.text.trim());
                                            Navigator.pop(context);
                                          }, child: const Text('添加')),
                                        ],
                                      ),
                                    );
                                  },
                                  child: const Text('+ 添加冲突', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Build and verify**

```powershell
cd D:\XJTU-Course-Genius\frontend; flutter build windows
```

Expected: build succeeds. Full sidebar + 3-panel layout working.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/home_page.dart
git commit -m "feat: rewrite home page with sidebar, course cards, selection/config panels"
```

---

### Task 8: Build and final verify

**Files:** all

- [ ] **Step 1: Full clean build**

```powershell
cd D:\XJTU-Course-Genius\frontend; flutter clean; flutter pub get; flutter build windows
```

Expected: clean build succeeds, output at `build\windows\x64\runner\Release\xjtu_course_genius.exe`.

- [ ] **Step 2: Run flutter analyze**

```powershell
cd D:\XJTU-Course-Genius\frontend; flutter analyze
```

Expected: no errors, warnings only for pre-existing deprecated APIs (acceptable).

- [ ] **Step 3: Run tests**

```powershell
cd D:\XJTU-Course-Genius\frontend; flutter test
```

Expected: widget test passes (checks login page renders).

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "refactor: complete frontend redesign with sidebar, Noto Sans SC, polished pages"
```
