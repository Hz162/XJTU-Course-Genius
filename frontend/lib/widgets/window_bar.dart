import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

const _channel = MethodChannel('com.xjtu.genius/ime');

class WindowBar extends StatelessWidget {
  final Widget? leading;
  const WindowBar({super.key, this.leading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          if (leading != null) leading!,
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _channel.invokeMethod('windowDrag'),
            ),
          ),
          const _WinBtn(Icons.minimize_rounded, 'windowMinimize'),
          const _WinBtn(Icons.crop_square_rounded, 'windowMaximize'),
          const _WinBtn(Icons.close_rounded, 'windowClose', isClose: true),
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
      width: 44, height: 40,
      child: InkWell(
        onTap: () => _channel.invokeMethod(method),
        child: Center(
          child: Icon(icon, size: 18,
              color: isClose ? dangerColor : textMuted),
        ),
      ),
    );
  }
}
