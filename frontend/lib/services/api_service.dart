import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/course.dart';

/// Thrown when the backend session has expired and auto-re-login failed.
class SessionExpiredException implements Exception {
  @override
  String toString() => '会话已过期，请重新登录';
}

class ApiService {
  static const _defaultPort = 18720;

  String _baseUrl = 'http://127.0.0.1:$_defaultPort/api';

  String get baseUrl => _baseUrl;

  final http.Client _client = http.Client();

  // ── Port discovery ──

  static String get _configDir {
    if (Platform.isWindows) {
      final appdata = Platform.environment['APPDATA'] ??
          '${Platform.environment['USERPROFILE']}\\AppData\\Roaming';
      return '$appdata\\xjtu-genius';
    } else if (Platform.isMacOS) {
      return '${Platform.environment['HOME']}/Library/Application Support/xjtu-genius';
    } else {
      final xdg = Platform.environment['XDG_CONFIG_HOME'] ??
          '${Platform.environment['HOME']}/.config';
      return '$xdg/xjtu-genius';
    }
  }

  /// Connect directly to a backend at the given port.
  void connectPort(int port) {
    _baseUrl = 'http://127.0.0.1:$port/api';
  }

  /// Auto-discover backend: first try known port, then scan.
  /// Use [connectPort] if you already know the backend's port.
  Future<String> discover() async {
    // 1) Try reading port file written by backend (shared file, last write wins)
    try {
      final portFile = File('$_configDir${Platform.pathSeparator}port');
      if (await portFile.exists()) {
        final port = (await portFile.readAsString()).trim();
        if (port.isNotEmpty) {
          final url = 'http://127.0.0.1:$port/api';
          if (await _ping(url)) {
            _baseUrl = url;
            return _baseUrl;
          }
        }
      }
    } catch (_) {}

    // 2) Try default port and nearby ports
    for (var p = _defaultPort; p < _defaultPort + 30; p++) {
      final url = 'http://127.0.0.1:$p/api';
      if (await _ping(url)) {
        _baseUrl = url;
        return _baseUrl;
      }
    }

    // 3) Keep current URL (user may configure later)
    return _baseUrl;
  }

  Future<bool> _ping(String url) async {
    try {
      final resp = await http
          .get(Uri.parse('$url/session/check'))
          .timeout(const Duration(milliseconds: 800));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Set a custom backend URL (e.g. for remote servers)
  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/api') ? url : '$url/api';
  }

  // ── HTTP helpers ──

  bool _reloginInProgress = false;

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    http.Response resp;
    final headers = {'Content-Type': 'application/json'};

    switch (method) {
      case 'GET':
        resp = await _client.get(uri, headers: headers);
        break;
      case 'POST':
        resp = await _client.post(uri, headers: headers, body: jsonEncode(body));
        break;
      default:
        throw Exception('Unknown method $method');
    }

    // Auto re-login on session expiry
    if (resp.body.trimLeft().startsWith('<') && !_reloginInProgress) {
      _reloginInProgress = true;
      try {
        debugPrint('[ApiService] session expired, auto relogin...');
        final reloginOk = await _tryRelogin();
        if (reloginOk) {
          debugPrint('[ApiService] relogin OK, retrying $path');
          return _request(method, path, body: body);
        }
      } finally {
        _reloginInProgress = false;
      }
      throw SessionExpiredException();
    }

    if (resp.statusCode >= 400) {
      try {
        final err = jsonDecode(resp.body);
        throw Exception(err['error'] ?? '请求失败');
      } catch (e) {
        if (e is SessionExpiredException || e.toString().contains('会话')) rethrow;
        throw Exception('服务器错误 (${resp.statusCode})');
      }
    }

    try {
      return jsonDecode(resp.body);
    } catch (_) {
      throw Exception('服务器返回异常数据');
    }
  }

  Future<bool> _tryRelogin() async {
    try {
      final resp = await _client.post(
        Uri.parse('$_baseUrl/relogin'),
        headers: {'Content-Type': 'application/json'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['status'] == 'ok';
      }
    } catch (_) {}
    return false;
  }

  // ── Login & MFA ──

  Future<Map<String, dynamic>> login(String account, String password, {String captcha = ''}) async {
    final data = await _request('POST', '/login', body: {'account': account, 'password': password, 'captcha': captcha});
    return data as Map<String, dynamic>;
  }

  Future<List<int>> getCaptchaImage() async {
    final uri = Uri.parse('$_baseUrl/captcha');
    final resp = await _client.get(uri);
    if (resp.statusCode == 200) {
      return resp.bodyBytes.toList();
    }
    throw Exception('获取验证码失败');
  }

  Future<Map<String, dynamic>> mfaInit(String method) async {
    final data = await _request('POST', '/mfa/init', body: {'method': method});
    return data as Map<String, dynamic>;
  }

  Future<void> mfaSend() => _request('POST', '/mfa/send');

  Future<Map<String, dynamic>> mfaVerify(String code) async {
    final data = await _request('POST', '/mfa/verify', body: {'code': code});
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> chooseAccount(String accountType) async {
    final data = await _request('POST', '/account/choose', body: {'accountType': accountType});
    return data as Map<String, dynamic>;
  }

  // ── Batches ──

  Future<List<BatchInfo>> getBatches() async {
    final data = await _request('GET', '/batches');
    return (data as List).map((j) => BatchInfo.fromJson(j)).toList();
  }

  Future<Map<String, dynamic>> enterRound(String batchCode) async {
    final data = await _request('POST', '/batches/select', body: {'batchCode': batchCode});
    return data as Map<String, dynamic>;
  }

  // ── Courses ──

  Future<List<dynamic>> getSelectedCourses() async {
    final data = await _request('GET', '/courses/selected');
    return (data is List) ? data : <dynamic>[];
  }

  Future<void> dropCourse(String teachingClassId) =>
      _request('POST', '/courses/drop', body: {'teachingClassId': teachingClassId});

  Future<Map<String, dynamic>> queryCourses(String type, {String keyword = ''}) async {
    final qs = keyword.isNotEmpty ? '?keyword=$keyword' : '';
    final data = await _request('GET', '/courses/query/$type$qs');
    return data as Map<String, dynamic>;
  }

  // ── Selection ──

  Future<void> startSelection() => _request('POST', '/selection/start');
  Future<void> stopSelection() => _request('POST', '/selection/stop');

  Future<SelectionStatus> getSelectionStatus() async {
    final data = await _request('GET', '/selection/status');
    return SelectionStatus.fromJson(data);
  }

  // ── Config ──

  Future<Map<String, dynamic>> getConfig() async {
    final data = await _request('GET', '/config');
    return data as Map<String, dynamic>;
  }

  Future<void> saveConfig(List<List<String>> course, List<List<String>> delcourses) =>
      _request('POST', '/config', body: {'course': course, 'delcourses': delcourses});

  // ── Campus ──

  Future<List<dynamic>> getCampusList() async {
    final data = await _request('GET', '/campus');
    return (data is List) ? data : <dynamic>[];
  }

  Future<void> setCampus(String campus) =>
      _request('POST', '/campus/set', body: {'campus': campus});

  // ── Session ──

  Future<bool> checkSession() async {
    final data = await _request('GET', '/session/check');
    return data['alive'] ?? false;
  }

  Future<void> relogin() => _request('POST', '/relogin');
}
