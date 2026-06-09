import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_page.dart';

class RoundPage extends StatefulWidget {
  final ApiService api;
  const RoundPage({super.key, required this.api});

  @override
  State<RoundPage> createState() => _RoundPageState();
}

class _RoundPageState extends State<RoundPage> {
  List<BatchInfo> _batches = [];
  int _selectedIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final batches = await widget.api.getBatches();
      if (!mounted) return;
      setState(() {
        _batches = batches;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('获取轮次失败: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  Future<void> _confirm() async {
    if (_batches.isEmpty) return;
    final batch = _batches[_selectedIndex];
    if (batch.canSelect == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请选择正确的可选轮次！'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.api.enterRound(batch.code);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage(api: widget.api)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('进入轮次失败: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(title: const Text('选择选课轮次')),
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
              : _batches.isEmpty
                  ? const Center(
                      child: Text('请在开放选课时使用！',
                          style: TextStyle(fontSize: 16, color: Color(0xFF909399))))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _selectedIndex,
                          items: List.generate(_batches.length, (i) {
                            return DropdownMenuItem(
                              value: i,
                              child: Text(_batches[i].name,
                                  style: const TextStyle(fontSize: 16)),
                            );
                          }),
                          onChanged: (v) =>
                              setState(() => _selectedIndex = v ?? 0),
                          decoration:
                              const InputDecoration(labelText: '选课轮次'),
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
                                    _batches[_selectedIndex].canSelect == '0'
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
                                    borderRadius: BorderRadius.circular(10)),
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
