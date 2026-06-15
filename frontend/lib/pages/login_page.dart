import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/backend_service.dart';
import '../services/ime_service.dart';
import '../theme/app_theme.dart';
import '../widgets/window_bar.dart';
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
  final _accountFocus = FocusNode();
  final _pwdFocus = FocusNode();
  final _captchaFocus = FocusNode();
  final _api = ApiService();
  bool _loading = false;
  bool _captchaRequired = false;
  Uint8List? _captchaImg;
  String _campus = '';

  @override
  void initState() {
    super.initState();
    // Multi-instance: each Flutter app connects to its own backend subprocess
    BackendService().port.then((port) => _api.connectPort(port));
    _accountFocus.addListener(() {
      if (_accountFocus.hasFocus) {
        ImeService.onFieldFocus();
      } else {
        ImeService.onFieldBlur();
      }
    });
    _pwdFocus.addListener(() {
      if (_pwdFocus.hasFocus) {
        ImeService.onFieldFocus();
      } else {
        ImeService.onFieldBlur();
      }
    });
    _captchaFocus.addListener(() {
      if (_captchaFocus.hasFocus) {
        ImeService.onFieldFocus();
      } else {
        ImeService.onFieldBlur();
      }
    });
  }

  @override
  void dispose() {
    ImeService.forceRestore();
    _accountCtl.dispose();
    _pwdCtl.dispose();
    _captchaCtl.dispose();
    _accountFocus.dispose();
    _pwdFocus.dispose();
    _captchaFocus.dispose();
    super.dispose();
  }

  void _resetCaptcha() {
    if (!_captchaRequired) return;
    setState(() {
      _captchaRequired = false;
      _captchaImg = null;
      _captchaCtl.clear();
    });
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
        setState(() {
          _captchaRequired = true;
          _loading = false;
        });
        _loadCaptcha();
        if (result['error'] != null) {
          _showError(result['error']);
        }
        return;
      }

      if (result['account_choice_required'] == true) {
        final choices =
            List<Map<String, String>>.from(result['choices'] ?? []);
        if (!mounted) return;
        setState(() => _loading = false);
        final chosen = await _showAccountChoice(choices);
        if (chosen == null) return;
        setState(() => _loading = true);
        final choiceResult = await _api.chooseAccount(chosen);
        if (choiceResult['success'] == true) {
          if (choiceResult['campus'] != null) _campus = choiceResult['campus'];
          await _gotoRounds();
        } else {
          _showError(choiceResult['error'] ?? '账户选择失败');
        }
        return;
      }

      if (result['mfa_required'] == true) {
        if (!mounted) return;
        if (result['campus'] != null) _campus = result['campus'];
        final ok = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => MfaPage(api: _api)),
        );
        if (ok == true) await _gotoRounds();
      } else if (result['success'] == true) {
        if (result['campus'] != null) _campus = result['campus'];
        await _gotoRounds();
      } else {
        _showError(result['error'] ?? '登录失败');
      }
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _gotoRounds() async {
    if (!mounted) return;
    await ImeService.forceRestore();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoundPage(api: _api, campus: _campus)),
    );
  }

  Future<String?> _showAccountChoice(
      List<Map<String, String>> choices) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择登录身份'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: choices
              .map((c) => ListTile(
                    title: Text(c['name'] ?? ''),
                    onTap: () {
                      final type = (c['name'] ?? '').contains('本科')
                          ? 'undergraduate'
                          : 'postgraduate';
                      Navigator.pop(ctx, type);
                    },
                  ))
              .toList(),
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
      body: Column(
        children: [
          const WindowBar(),
          Expanded(
            child: Focus(
              onKeyEvent: _handleKey,
              child: Center(
                child: _loading
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                  strokeWidth: 3)),
                          SizedBox(height: 16),
                          Text('正在登录...',
                              style:
                                  TextStyle(color: Color(0xFF909399))),
                        ],
                      )
                    : _buildForm(),
              ),
            ),
          ),
        ],
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
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 24,
              offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogo(),
          const SizedBox(height: 12),
          const Text('西安交通大学',
              style: TextStyle(fontSize: 13, color: Color(0xFF909399))),
          const SizedBox(height: 4),
          const Text('统一身份认证',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF303133))),
          const SizedBox(height: 28),
          _buildInputs(),
          if (_captchaRequired) ...[
            const SizedBox(height: 12),
            _buildCaptcha(),
          ],
          const SizedBox(height: 24),
          _buildLoginButton(),
          const SizedBox(height: 12),
          const Text('Ctrl + Enter 快速登录',
              style: TextStyle(fontSize: 11, color: Color(0xFFC0C4CC))),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset('assets/logo.png',
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                gradient: primaryGradient,
              ),
              child: const Center(
                  child: Text('西',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)))),
      ),
    );
  }

  Widget _buildInputs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000),
              blurRadius: 3,
              offset: Offset(0, 1))
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _accountCtl,
            focusNode: _accountFocus,
            keyboardType: TextInputType.emailAddress,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[一-鿿]')),
            ],
            decoration: const InputDecoration(
              hintText: '请输入账号',
              prefixIcon:
                  Icon(Icons.person_outline, color: Color(0xFFC0C4CC)),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFEBEEF5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFEBEEF5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(10)),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
            ),
            onChanged: (_) => _resetCaptcha(),
            textInputAction: TextInputAction.next,
          ),
          Container(height: 1, color: const Color(0xFFF2F6FC)),
          TextField(
            controller: _pwdCtl,
            focusNode: _pwdFocus,
            keyboardType: TextInputType.visiblePassword,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[一-鿿]')),
            ],
            decoration: const InputDecoration(
              hintText: '请输入密码',
              prefixIcon:
                  Icon(Icons.lock_outline, color: Color(0xFFC0C4CC)),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFEBEEF5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(10)),
                borderSide: BorderSide(color: Color(0xFFEBEEF5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(10)),
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
          focusNode: _captchaFocus,
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
      width: double.infinity,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: _loading ? null : primaryGradient,
          boxShadow: _loading
              ? null
              : const [
                  BoxShadow(
                      color: Color(0x4D409EFF),
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
        ),
        child: FilledButton(
          onPressed: _loading ? null : _login,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('登 录',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
