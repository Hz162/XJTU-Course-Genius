import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_page.dart';

class RoundPage extends StatefulWidget {
  final ApiService api;
  final String campus;
  const RoundPage({super.key, required this.api, this.campus = ''});

  @override
  State<RoundPage> createState() => _RoundPageState();
}

class _RoundPageState extends State<RoundPage> {
  List<BatchInfo> _batches = [];
  int _selectedIndex = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final batches = await widget.api.getBatches();
      if (!mounted) return;
      setState(() {
        _batches = batches;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _confirm() async {
    if (_batches.isEmpty) return;
    final batch = _batches[_selectedIndex];
    if (batch.canSelect == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请选择正确的可选轮次！'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.api.enterRound(batch.code);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
                HomePage(api: widget.api, initialCampus: widget.campus)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '进入轮次失败: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off, size: 48, color: Color(0xFFC0C4CC)),
        const SizedBox(height: 16),
        Text(_error ?? '未知错误',
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 14, color: Color(0xFF909399))),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: primaryGradient,
            ),
            child: FilledButton.icon(
              onPressed: _loadBatches,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
          ),
          child: const Text('返回登录页'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('选择选课轮次'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 24,
                  offset: Offset(0, 4)),
            ],
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorView()
                  : _batches.isEmpty
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('请在开放选课时使用！',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF909399))),
                            const SizedBox(height: 24),
                            OutlinedButton(
                              onPressed: _loadBatches,
                              child: const Text('刷新'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('返回登录页'),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButtonFormField<int>(
                              initialValue: _selectedIndex,
                              isExpanded: true,
                              menuMaxHeight: 300,
                              selectedItemBuilder: (ctx) {
                                return List.generate(_batches.length, (i) {
                                  return Text(_batches[i].name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: textPrimary,
                                        fontFamily: 'NotoSansSC',
                                      ));
                                });
                              },
                              items: List.generate(_batches.length, (i) {
                                final b = _batches[i];
                                final selected = i == _selectedIndex;
                                return DropdownMenuItem(
                                  value: i,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? primaryColor.withAlpha(25)
                                                : surfaceSecondary,
                                            borderRadius: BorderRadius.circular(
                                                radiusSm),
                                          ),
                                          child: Icon(
                                            b.canSelect == '0'
                                                ? Icons.lock_outline_rounded
                                                : Icons.layers_rounded,
                                            size: 16,
                                            color: selected
                                                ? primaryColor
                                                : textMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(b.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: selected
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color: selected
                                                    ? primaryColor
                                                    : textPrimary,
                                                fontFamily: 'NotoSansSC',
                                              )),
                                        ),
                                        if (selected)
                                          const Icon(Icons.check_rounded,
                                              size: 20, color: primaryColor),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              onChanged: (v) =>
                                  setState(() => _selectedIndex = v ?? 0),
                              decoration: InputDecoration(
                                labelText: '选课轮次',
                                prefixIcon: const Icon(Icons.layers_rounded, color: primaryColor),
                                filled: true,
                                fillColor: surfaceSecondary,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(radiusMd),
                                  borderSide: const BorderSide(
                                      color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(radiusMd),
                                  borderSide: const BorderSide(
                                      color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(radiusMd),
                                  borderSide: const BorderSide(
                                      color: primaryColor, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              borderRadius:
                                  BorderRadius.circular(radiusLg),
                              dropdownColor: surfaceColor,
                              icon: const Icon(Icons.expand_more_rounded,
                                  color: textSecondary),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: textPrimary,
                                fontFamily: 'NotoSansSC',
                              ),
                            ),
                            if (_batches.isNotEmpty &&
                                _selectedIndex < _batches.length) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECF5FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        size: 16, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _batches[_selectedIndex]
                                                    .canSelect ==
                                                '0'
                                            ? '当前不在选课开放时间内'
                                            : '可选中，点击确定进入',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF409EFF)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: primaryGradient,
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0x4D409EFF),
                                        blurRadius: 8,
                                        offset: Offset(0, 2)),
                                  ],
                                ),
                                child: FilledButton(
                                  onPressed: _confirm,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: const Text('确定',
                                      style: TextStyle(fontSize: 18)),
                                ),
                              ),
                            ),
                          ],
                        ),
        ),
      ),
    );
  }
}
