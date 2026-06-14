import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

const _channel = MethodChannel('com.xjtu.genius/ime');

class WindowBar extends StatelessWidget {
  const WindowBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: Colors.transparent,
      child: Row(
        children: [
          const Spacer(),
          _WinBtn(Icons.minimize_rounded, 'windowMinimize'),
          _WinBtn(Icons.crop_square_rounded, 'windowMaximize'),
          _WinBtn(Icons.close_rounded, 'windowClose', isClose: true),
        ],
      ),
    );
  }
}

class _WinBtn extends StatelessWidget {
  final IconData icon;
  final String method;
  final bool isClose;
  const _WinBtn(this.icon, this.method, {this.isClose = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40, height: 32,
      child: InkWell(
        onTap: () => _channel.invokeMethod(method),
        child: Icon(icon, size: 16,
            color: isClose ? dangerColor : textMuted),
      ),
    );
  }
}
