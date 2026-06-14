import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/backend_service.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Auto-start backend
  final backend = BackendService();
  await backend.start();

  runApp(const CourseGeniusApp());
}

class CourseGeniusApp extends StatefulWidget {
  const CourseGeniusApp({super.key});

  @override
  State<CourseGeniusApp> createState() => _CourseGeniusAppState();
}

class _CourseGeniusAppState extends State<CourseGeniusApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      BackendService().stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XJTU Course Genius',
      theme: appTheme(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),
      home: const LoginPage(),
    );
  }
}
