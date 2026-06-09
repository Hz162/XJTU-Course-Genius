import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImeService {
  static const _channel = MethodChannel('com.xjtu.genius/ime');
  static bool _saved = false;
  static bool _observerRegistered = false;
  static Timer? _restoreTimer;
  static int _focusCount = 0;

  static void _ensureObserver() {
    if (_observerRegistered) return;
    _observerRegistered = true;
    WidgetsBinding.instance.addObserver(_ImeLifecycleObserver());
  }

  static Future<void> onFieldFocus() async {
    _restoreTimer?.cancel();
    _restoreTimer = null;
    _focusCount++;
    _ensureObserver();
    try {
      if (!_saved) {
        await _channel.invokeMethod('saveCurrentIme');
        _saved = true;
      }
      await _channel.invokeMethod('switchToEnglish');
    } catch (_) {}
  }

  static void onFieldBlur() {
    _focusCount--;
    if (_focusCount > 0) return;
    if (!_saved) return;
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(milliseconds: 50), () async {
      try {
        await _channel.invokeMethod('restoreIme');
        _saved = false;
      } catch (_) {}
    });
  }

  static Future<void> forceRestore() async {
    _restoreTimer?.cancel();
    _restoreTimer = null;
    _focusCount = 0;
    if (!_saved) return;
    _saved = false;
    try {
      await _channel.invokeMethod('restoreIme');
    } catch (_) {}
  }
}

class _ImeLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ImeService._restoreTimer?.cancel();
      ImeService._restoreTimer = null;
    }
  }
}
