import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/course.dart';

class ApiService {
  static const baseUrl = 'http://127.0.0.1:18720/api';

  final http.Client _client = http.Client();

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
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

    if (resp.statusCode >= 400) {
      final err = jsonDecode(resp.body);
      throw Exception(err['error'] ?? '请求失败');
    }
    return jsonDecode(resp.body);
  }

  // ── Login & MFA ──

  Future<Map<String, dynamic>> login(String account, String password, {String captcha = ''}) async {
    final data = await _request('POST', '/login', body: {'account': account, 'password': password, 'captcha': captcha});
    return data as Map<String, dynamic>;
  }

  Future<List<int>> getCaptchaImage() async {
    final uri = Uri.parse('$baseUrl/captcha');
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
