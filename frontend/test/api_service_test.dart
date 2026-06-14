import 'package:flutter_test/flutter_test.dart';
import 'package:xjtu_course_genius/services/api_service.dart';

void main() {
  late ApiService api;

  setUp(() {
    api = ApiService();
  });

  group('Login flows', () {
    test('direct login success returns campus', () async {
      final result = await api.login('testuser', 'testpass');
      expect(result['success'], true);
      expect(result['campus'], 'xq');
    });

    test('captcha required flow', () async {
      final result = await api.login('captcha', 'testpass');
      expect(result['captcha_required'], true);
      expect(result['success'], false);
    });

    test('MFA required flow', () async {
      final result = await api.login('mfa', 'testpass');
      expect(result['mfa_required'], true);
      expect(result['success'], false);
    });

    test('account choice required flow', () async {
      final result = await api.login('choice', 'testpass');
      expect(result['account_choice_required'], true);
      expect(result['choices']?.isNotEmpty, true);
      expect(result['choices'].length, 2);
    });

    test('login error returns message', () async {
      final result = await api.login('error', 'testpass');
      expect(result['success'], false);
      expect(result['error'], isNotEmpty);
    });
  });

  group('MFA', () {
    test('init returns target', () async {
      final result = await api.mfaInit('securephone');
      expect(result['target'], isNotEmpty);
    });

    test('send succeeds', () async {
      await api.mfaSend();
    });

    test('verify with correct code succeeds', () async {
      await api.mfaVerify('123456');
    });

    test('verify with wrong code throws', () async {
      expect(() => api.mfaVerify('000000'), throwsException);
    });
  });

  group('Account choice', () {
    test('choosing account succeeds with campus', () async {
      final result = await api.chooseAccount('undergraduate');
      expect(result['success'], true);
      expect(result['campus'], 'yt');
    });
  });

  group('Batches & Campus', () {
    test('getBatches returns list', () async {
      final batches = await api.getBatches();
      expect(batches.isNotEmpty, true);
      expect(batches.first.name, isNotEmpty);
      expect(batches.first.code, isNotEmpty);
    });

    test('enterRound succeeds', () async {
      await api.enterRound('batch_2025_1');
    });

    test('getCampusList returns campuses', () async {
      final campuses = await api.getCampusList();
      expect(campuses.length, 3);
      expect(campuses[0]['code'], isNotEmpty);
      expect(campuses[0]['name'], isNotEmpty);
    });

    test('setCampus succeeds', () async {
      await api.setCampus('xq');
    });
  });

  group('Course queries', () {
    test('getSelectedCourses returns list', () async {
      final courses = await api.getSelectedCourses();
      expect(courses.isNotEmpty, true);
      expect(courses[0]['courseName'], isNotEmpty);
      // Each course should have classType for display
      expect(courses[0]['classType'], isNotEmpty);
    });

    test('queryCourses by type returns courses', () async {
      for (final type in ['TJKC', 'FANKC', 'FAWKC', 'XGXK', 'TYKC']) {
        final result = await api.queryCourses(type);
        final courses = result['courses'] as List;
        expect(courses.isNotEmpty, true, reason: '$type should have courses');
      }
    });

    test('queryCourses with all type returns all courses', () async {
      final result = await api.queryCourses('all');
      final courses = result['courses'] as List;
      expect(courses.length, greaterThanOrEqualTo(5));
    });

    test('queryCourses with keyword filters', () async {
      final result = await api.queryCourses('all', keyword: '数学');
      final courses = result['courses'] as List;
      expect(courses.every((c) =>
          c['courseName'].toString().contains('数学') ||
          c['teacherName'].toString().contains('数学')), true);
    });
  });

  group('Config', () {
    test('save and load config', () async {
      final wishlist = [
        ['2024AUTD113267001', '高等数学 I-1', '张教授', '主楼A-301', 'TJKC', 'xq'],
      ];
      final delcourses = [<String>[]];

      await api.saveConfig(wishlist, delcourses);

      final cfg = await api.getConfig();
      final loaded = (cfg['course'] as List?) ?? [];
      expect(loaded.isNotEmpty, true);
      expect(loaded[0][0], '2024AUTD113267001');
    });
  });

  group('Selection', () {
    setUp(() async {
      // Ensure config is set before selection tests
      final wishlist = [
        ['2024AUTD113267001', '高等数学 I-1', '张教授', '主楼A-301', 'TJKC', 'xq'],
        ['2024AUTN11003FAN01', '计算机网络', '赵教授', '电信楼A-401', 'FANKC', 'xq'],
      ];
      await api.saveConfig(wishlist, [
        <String>[],
        <String>[],
      ]);
    });

    test('start selection succeeds', () async {
      await api.startSelection();
    });

    test('get status returns running initially', () async {
      await api.startSelection();
      final status = await api.getSelectionStatus();
      expect(status.running, true);
      expect(status.totalCourse, greaterThanOrEqualTo(0));
    });

    test('stop selection succeeds', () async {
      await api.startSelection();
      await api.stopSelection();
    });

    test('full selection cycle completes', () async {
      await api.startSelection();
      // Wait for selection to complete (progress ticks per second)
      bool running = true;
      int attempts = 0;
      while (running && attempts < 15) {
        await Future.delayed(const Duration(seconds: 1));
        final status = await api.getSelectionStatus();
        running = status.running;
        attempts++;
      }
      expect(running, false, reason: 'Selection should auto-stop');
      expect(attempts, lessThan(15), reason: 'Should complete within timeout');
    });
  });

  group('Session', () {
    test('check session returns alive', () async {
      final alive = await api.checkSession();
      expect(alive, true);
    });
  });
}
