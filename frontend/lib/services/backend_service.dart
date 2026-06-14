import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class BackendService {
  static final BackendService _instance = BackendService._();
  factory BackendService() => _instance;
  BackendService._();

  Process? _process;

  String get _exeName {
    if (Platform.isWindows) return 'xjtu-genius.exe';
    return 'xjtu-genius';
  }

  /// Find the backend binary: same dir as Flutter exe, then project dir, then PATH.
  String? _findBackend() {
    final flutterExe = File(Platform.resolvedExecutable);
    final flutterDir = flutterExe.parent;

    // 1) Same directory as Flutter executable (release layout)
    final sibling = File('${flutterDir.path}${Platform.pathSeparator}$_exeName');
    if (sibling.existsSync()) return sibling.path;

    // 2) Project backend directory (dev layout)
    // Navigate up from build/.../runner/Debug|Release to project root
    var dir = flutterDir;
    for (var i = 0; i < 8; i++) {
      final candidate = File('${dir.path}${Platform.pathSeparator}backend$_exeName');
      if (candidate.existsSync()) return candidate.path;
      dir = dir.parent;
    }

    // 3) Backend directly inside project directory
    final backendDir = '${flutterDir.path}${Platform.pathSeparator}backend';
    final backendFile = File('$backendDir${Platform.pathSeparator}$_exeName');
    if (backendFile.existsSync()) return backendFile.path;

    return null;
  }

  /// Start the backend. Safe to call multiple times.
  Future<bool> start() async {
    if (_process != null) return true;

    final path = _findBackend();
    if (path == null) {
      debugPrint('[BackendService] backend binary not found');
      return false;
    }

    try {
      _process = await Process.start(
        path,
        [],
        mode: ProcessStartMode.normal,
      );

      // Log backend output
      _process!.stdout
          .transform(const SystemEncoding().decoder)
          .listen((s) => debugPrint('[backend] $s'));
      _process!.stderr
          .transform(const SystemEncoding().decoder)
          .listen((s) => debugPrint('[backend] $s'));

      // Detect crash
      _process!.exitCode.then((code) {
        debugPrint('[BackendService] backend exited with code $code');
        _process = null;
      });

      debugPrint('[BackendService] backend started: $path');
      return true;
    } catch (e) {
      debugPrint('[BackendService] failed to start backend: $e');
      return false;
    }
  }

  /// Stop the backend process.
  Future<void> stop() async {
    if (_process == null) return;
    try {
      _process!.kill(ProcessSignal.sigterm);
      await _process!.exitCode.timeout(const Duration(seconds: 3));
    } catch (_) {
      _process!.kill(ProcessSignal.sigkill);
    }
    _process = null;
    debugPrint('[BackendService] backend stopped');
  }
}
