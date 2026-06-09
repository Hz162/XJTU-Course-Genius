import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/ime_service.dart';
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
  final _codeFocus = FocusNode();
  bool _sending = false;
  bool _initLoading = true;
  int _countdown = 0;
  Timer? _timer;
  bool _codeSent = false;

  @override
  void initState() {
    super.initState();
    _codeFocus.addListener(() {
      if (_codeFocus.hasFocus) {
        ImeService.onFieldFocus();
      } else {
        ImeService.onFieldBlur();
      }
    });
    _initMethod();
  }

  @override
  void dispose() {
    ImeService.forceRestore();
    _codeCtl.dispose();
    _codeFocus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initMethod() async {
    setState(() => _initLoading = true);
    try {
      final result = await widget.api.mfaInit(_method);
      if (!mounted) return;
      setState(() {
        _target = result['target'] ?? '';
        _initLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initLoading = false);
      _showError('初始化失败');
    }
  }

  Future<void> _sendCode() async {
    setState(() => _sending = true);
    try {
      await widget.api.mfaSend();
      setState(() => _codeSent = true);
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
        if (_countdown > 1) {
          _countdown--;
        } else {
          _countdown = 0;
          t.cancel();
        }
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
    _timer?.cancel();
    setState(() {
      _method = m;
      _codeSent = false;
      _countdown = 0;
      _codeCtl.clear();
    });
    await _initMethod();
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
              BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 24,
                  offset: Offset(0, 4)),
            ],
          ),
          child: _initLoading
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
                        ? '发送至 ${_formatTarget(_target)}'
                        : '获取验证码'),
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: primaryGradient,
          ),
          child: Center(
              child: Text('$step',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF303133))),
        ),
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
              Icon(icon,
                  color: selected ? primaryColor : const Color(0xFF909399),
                  size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
        if (!_codeSent)
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: primaryGradient,
                ),
                child: FilledButton(
                  onPressed: (_sending) ? null : _sendCode,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(_sending ? '发送中...' : '发送验证码',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          )
        else ...[
          Expanded(
            flex: 3,
            child: TextField(
              controller: _codeCtl,
              focusNode: _codeFocus,
              inputFormatters: [
                FilteringTextInputFormatter.deny(
                    RegExp(r'[一-鿿　-〿＀-￯]')),
              ],
              decoration: const InputDecoration(
                hintText: '输入验证码',
                prefixIcon:
                    Icon(Icons.pin_outlined, color: Color(0xFFC0C4CC)),
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
              onPressed:
                  (_countdown == 0 && !_sending) ? _sendCode : null,
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(
                _countdown > 0 ? '${_countdown}s' : '重发',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: _codeSent ? primaryGradient : null,
          color: _codeSent ? null : const Color(0xFFDCDFE6),
          boxShadow: _codeSent
              ? const [
                  BoxShadow(
                      color: Color(0x4D409EFF),
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ]
              : null,
        ),
        child: FilledButton(
          onPressed: _codeSent ? _verify : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('验 证',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  String _formatTarget(String target) {
    if (target.isEmpty) return target;
    if (target.contains('@')) {
      final parts = target.split('@');
      final name = parts[0];
      if (name.length <= 3) return '$name@${parts[1]}';
      return '${name.substring(0, 3)}***@${parts[1]}';
    }
    if (target.length <= 4) return target;
    return '${target.substring(0, 3)}****${target.substring(target.length - 4)}';
  }
}
