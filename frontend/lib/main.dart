import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';
import 'widgets/window_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CourseGeniusApp());
}

class CourseGeniusApp extends StatelessWidget {
  const CourseGeniusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XJTU Course Genius',
      theme: appTheme(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => Column(
        children: [
          const WindowBar(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
      ),
      home: const LoginPage(),
    );
  }
}
