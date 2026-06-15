import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class BackendService {
  static final BackendService _instance = BackendService._();
  factory BackendService() => _instance;
  BackendService._();

  Process? _process;
  final _portCompleter = Completer<int>();

  /// Returns the backend port once it has been started and the port is known.
  Future<int> get port => _portCompleter.future;

  String get _exeName {
    if (Platform.isWindows) return 'xjtu-genius.exe';
    return 'xjtu-genius';
  }

  /// Find the backend binary.
  String? _findBackend() {
    final flutterExe = File(Platform.resolvedExecutable);
    final flutterDir = flutterExe.parent;

    // 1) Same directory as Flutter executable (release layout)
    final sibling =
        File('${flutterDir.path}${Platform.pathSeparator}$_exeName');
    if (sibling.existsSync()) return sibling.path;

    // 2) Project backend directory (dev layout)
    var dir = flutterDir;
    for (var i = 0; i < 8; i++) {
      final candidate =
          File('${dir.path}${Platform.pathSeparator}backend$_exeName');
      if (candidate.existsSync()) return candidate.path;
      dir = dir.parent;
    }

    // 3) Backend inside project directory
    final backendDir = '${flutterDir.path}${Platform.pathSeparator}backend';
    final backendFile =
        File('$backendDir${Platform.pathSeparator}$_exeName');
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

      // Parse PORT= line from stdout for direct port discovery
      final completer = _portCompleter;
      _process!.stdout
          .transform(const SystemEncoding().decoder)
          .listen((chunk) {
        for (final line in chunk.split('\n')) {
          debugPrint('[backend] $line');
          if (!completer.isCompleted && line.startsWith('PORT=')) {
            final port = int.tryParse(line.substring(5).trim());
            if (port != null) {
              completer.complete(port);
              debugPrint('[BackendService] backend port: $port');
            }
          }
        }
      });

      _process!.stderr
          .transform(const SystemEncoding().decoder)
          .listen((s) => debugPrint('[backend-err] $s'));

      _process!.exitCode.then((code) {
        debugPrint('[BackendService] backend exited with code $code');
        if (!_portCompleter.isCompleted) {
          _portCompleter.completeError('Backend exited before announcing port');
        }
        _process = null;
      });

      debugPrint('[BackendService] backend started: $path');
      return true;
    } catch (e) {
      debugPrint('[BackendService] failed to start backend: $e');
      if (!_portCompleter.isCompleted) {
        _portCompleter.completeError(e);
      }
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
