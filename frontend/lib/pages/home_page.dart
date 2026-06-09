import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/course.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';

class HomePage extends StatefulWidget {
  final ApiService api;
  const HomePage({super.key, required this.api});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late ApiService api;

  SidebarItem _currentItem = SidebarItem.selected;
  String _currentView = 'selected';
  String _keyword = '';
  final _keywordCtl = TextEditingController();
  bool _loading = false;
  List<dynamic> _tableData = [];

  List<dynamic> _campusList = [];
  String _currentCampus = '';

  List<List<String>> _wishList = [];
  List<List<String>> _delCourses = [];

  SelectionStatus? _selStatus;
  Timer? _statusTimer;
  bool _selecting = false;

  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    api = widget.api;
    _loadConfig();
    _loadCampus();
  }

  @override
  void dispose() {
    _keywordCtl.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final cfg = await api.getConfig();
      setState(() {
        _wishList = List<List<String>>.from(
            (cfg['course'] as List?)?.map((e) => List<String>.from(e)) ?? []);
        _delCourses = List<List<String>>.from(
            (cfg['delcourses'] as List?)?.map((e) => List<String>.from(e)) ?? []);
      });
    } catch (_) {}
  }

  Future<void> _saveConfig() async {
    await api.saveConfig(_wishList, _delCourses);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _loadCampus() async {
    try {
      final list = await api.getCampusList();
      if (mounted) setState(() => _campusList = list);
    } catch (_) {}
  }

  Future<void> _loadCourseData(String view) async {
    setState(() => _loading = true);
    try {
      List<dynamic> data;
      if (view == 'selected') {
        data = await api.getSelectedCourses();
      } else {
        final result = await api.queryCourses(view, keyword: _keyword);
        data = (result['courses'] as List?) ?? [];
      }
      if (!mounted) return;
      setState(() {
        _tableData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _addToWishList(Map<String, dynamic> item) async {
    final entry = [
      (item['teachingClassId'] ?? '').toString(),
      (item['courseName'] ?? '').toString(),
      (item['teacherName'] ?? '').toString(),
      (item['teachingPlace'] ?? '').toString(),
      (item['classType'] ?? _currentView).toString(),
      _currentCampus,
    ];
    if (_wishList.any((e) => e.isNotEmpty && e[0] == entry[0])) {
      _showError('已在抢课列表中');
      return;
    }
    setState(() {
      _wishList.add(entry);
      _delCourses.add([]);
    });
    await _saveConfig();
  }

  Future<void> _removeWishItem(int idx) async {
    setState(() {
      _wishList.removeAt(idx);
      _delCourses.removeAt(idx);
    });
    await _saveConfig();
  }

  Future<void> _addConflictCourse(int wishIdx, String courseId) async {
    if (courseId.isEmpty || wishIdx >= _delCourses.length) return;
    setState(() {
      _delCourses[wishIdx].add(courseId);
      _delCourses[wishIdx] = _delCourses[wishIdx].toSet().toList();
    });
    await _saveConfig();
  }

  Future<void> _removeConflictCourse(int wishIdx, String courseId) async {
    if (wishIdx >= _delCourses.length) return;
    setState(() => _delCourses[wishIdx].remove(courseId));
    await _saveConfig();
  }

  Future<void> _toggleSelection() async {
    if (_selecting) {
      await api.stopSelection();
      _statusTimer?.cancel();
      setState(() => _selecting = false);
    } else {
      await api.startSelection();
      setState(() => _selecting = true);
      _pollStatus();
    }
  }

  void _pollStatus() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final s = await api.getSelectionStatus();
        if (!mounted) return;
        setState(() {
          _selStatus = s;
          if (!s.running) {
            _selecting = false;
            _statusTimer?.cancel();
          }
        });
      } catch (_) {}
    });
  }

  Future<void> _setCampus(String code) async {
    _currentCampus = code;
    await api.setCampus(code);
    if (mounted) setState(() {});
    _loadCourseData(_currentView);
  }

  void _onSidebarItem(SidebarItem item) {
    setState(() => _currentItem = item);
    switch (item) {
      case SidebarItem.selected:
        _currentView = 'selected';
      case SidebarItem.tjkc:
        _currentView = 'TJKC';
      case SidebarItem.fankc:
        _currentView = 'FANKC';
      case SidebarItem.fawkc:
        _currentView = 'FAWKC';
      case SidebarItem.xgxk:
        _currentView = 'XGXK';
      case SidebarItem.tykc:
        _currentView = 'TYKC';
      case SidebarItem.selection:
      case SidebarItem.config:
        break;
    }
    if (item != SidebarItem.selection && item != SidebarItem.config) {
      _loadCourseData(_currentView);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade400),
    );
  }

  KeyEventResult _handleGlobalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed;

    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyB) {
      _toggleSelection();
      return KeyEventResult.handled;
    }
    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyS) {
      _saveConfig();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f5) {
      if (_currentItem != SidebarItem.selection && _currentItem != SidebarItem.config) {
        _loadCourseData(_currentView);
      }
      return KeyEventResult.handled;
    }
    if (ctrl) {
      final digits = {
        LogicalKeyboardKey.digit1: SidebarItem.selected,
        LogicalKeyboardKey.digit2: SidebarItem.tjkc,
        LogicalKeyboardKey.digit3: SidebarItem.fankc,
        LogicalKeyboardKey.digit4: SidebarItem.fawkc,
        LogicalKeyboardKey.digit5: SidebarItem.xgxk,
        LogicalKeyboardKey.digit6: SidebarItem.tykc,
      };
      if (digits.containsKey(event.logicalKey)) {
        _onSidebarItem(digits[event.logicalKey]!);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleGlobalKey,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text('XJTU Course Genius'),
          leading: IconButton(
            icon: Icon(_sidebarCollapsed ? Icons.menu : Icons.menu_open),
            onPressed: () =>
                setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          ),
          actions: [
            if (_selecting)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)),
                  label: const Text('抢课中',
                      style: TextStyle(color: Colors.white)),
                  backgroundColor: Colors.green.shade500,
                ),
              ),
          ],
        ),
        body: Row(
          children: [
            Sidebar(
              selected: _currentItem,
              campus: _currentCampus,
              collapsed: _sidebarCollapsed,
              campusItems: _campusList.map<DropdownMenuItem<String>>((c) {
                return DropdownMenuItem<String>(
                  value: c['code']?.toString() ?? '',
                  child: Text(c['name']?.toString() ?? ''),
                );
              }).toList(),
              onItemSelected: _onSidebarItem,
              onCampusChanged: _setCampus,
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentItem) {
      case SidebarItem.selection:
        return _buildSelectionPanel();
      case SidebarItem.config:
        return _buildConfigPanel();
      default:
        return _buildCoursePanel();
    }
  }

  // ─── Course Browser Panel ───

  Widget _buildCoursePanel() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          Expanded(child: _buildCourseTable()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    if (_currentView == 'selected') return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _keywordCtl,
            decoration: const InputDecoration(hintText: '搜索课程名称或教师...'),
            onChanged: (v) => _keyword = v,
            onSubmitted: (_) => _loadCourseData(_currentView),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
            onPressed: () => _loadCourseData(_currentView),
            child: const Text('搜索')),
      ],
    );
  }

  Widget _buildCourseTable() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tableData.isEmpty) {
      return const Center(
          child: Text('暂无数据', style: TextStyle(color: Color(0xFF909399))));
    }
    return ListView.builder(
      itemCount: _tableData.length,
      itemBuilder: (_, i) {
        final item = _tableData[i];
        final id = (item['teachingClassId'] ?? '').toString();
        final inWish = _wishList.any((e) => e.isNotEmpty && e[0] == id);
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            title: Text((item['courseName'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(
              '${(item['teacherName'] ?? '').toString()} · ${(item['teachingPlace'] ?? '').toString()}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF909399)),
            ),
            leading: Text(id,
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFFC0C4CC))),
            trailing: _currentView == 'selected'
                ? Text(item['selected'] == true ? '✓' : '×',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: item['selected'] == true
                            ? Colors.green
                            : Colors.red))
                : inWish
                    ? const Text('已添加',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF67C23A)))
                    : TextButton(
                        onPressed: () => _addToWishList(item),
                        child: const Text('+ 抢课',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF409EFF))),
                      ),
          ),
        );
      },
    );
  }

  // ─── Selection Control Panel ───

  Widget _buildSelectionPanel() {
    final s = _selStatus;
    final doneCount = s?.flags.where((f) => f == 1).length ?? 0;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                      _selecting
                          ? Icons.sync
                          : Icons.play_circle_outline,
                      size: 64,
                      color: _selecting ? Colors.green : primaryColor),
                  const SizedBox(height: 16),
                  Text(_selecting ? '抢课进行中...' : '准备就绪',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 24),
                  if (s != null) ...[
                    LinearProgressIndicator(
                      value: s.totalCourse > 0
                          ? s.progress / s.totalCourse
                          : 0,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 12),
                    Text('进度 $doneCount / ${s.totalCourse}  ·  已抢到 $doneCount 门',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF909399))),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    height: 56,
                    child: FloatingActionButton.extended(
                      onPressed: _toggleSelection,
                      backgroundColor:
                          _selecting ? Colors.red.shade400 : primaryColor,
                      icon: Icon(
                          _selecting ? Icons.stop : Icons.play_arrow,
                          size: 28),
                      label: Text(_selecting ? '停 止' : '开 始',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_wishList.isNotEmpty && _selecting) ...[
            const SizedBox(height: 16),
            const Text('待抢课程',
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _wishList.length,
                itemBuilder: (_, i) {
                  final c = _wishList[i];
                  final done = s != null &&
                      i < s.flags.length &&
                      s.flags[i] == 1;
                  return ListTile(
                    leading: Icon(
                        done ? Icons.check_circle : Icons.pending,
                        color: done ? Colors.green : Colors.orange),
                    title: Text(c.length > 1 ? c[1] : c[0]),
                    subtitle: Text(c.isNotEmpty ? c[0] : ''),
                    trailing: done
                        ? null
                        : const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                  );
                },
              ),
            ),
          ],
          if (s != null && s.log.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('日志',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: s.log.length,
                  itemBuilder: (_, i) => Text(s.log[i],
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace')),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Config Panel ───

  Widget _buildConfigPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('抢课列表',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _loadConfig,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('读取'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saveConfig,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('保存'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_wishList.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: Text('暂无课程\n在课程浏览页面点击"+抢课"添加',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Color(0xFF909399)))),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _wishList.length,
                itemBuilder: (_, i) {
                  final c = _wishList[i];
                  final conflicts = i < _delCourses.length
                      ? _delCourses[i]
                      : <String>[];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      leading: Text(c.isNotEmpty ? c[0] : '?',
                          style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600)),
                      title: Text(c.length > 1 ? c[1] : '?',
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                          '${c.length > 3 ? c[3] : ''} · 冲突: ${conflicts.length}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF909399))),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () => _removeWishItem(i),
                      ),
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              if (conflicts.isNotEmpty) ...[
                                const Text('冲突课程:',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF909399))),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: conflicts.map((id) => Chip(
                                        label: Text(id,
                                            style: const TextStyle(
                                                fontSize: 11)),
                                        deleteIcon: const Icon(
                                            Icons.close,
                                            size: 14),
                                        onDeleted: () =>
                                            _removeConflictCourse(
                                                i, id),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize
                                                .shrinkWrap,
                                      )).toList(),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: TextField(
                                      decoration:
                                          const InputDecoration(
                                        hintText: '课程班号',
                                        isDense: true,
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 6),
                                      ),
                                      style: const TextStyle(
                                          fontSize: 12),
                                      onSubmitted: (v) {
                                        _addConflictCourse(i, v);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () {
                                      final ctl =
                                          TextEditingController();
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text(
                                              '添加冲突课程'),
                                          content: TextField(
                                              controller: ctl,
                                              autofocus: true,
                                              decoration:
                                                  const InputDecoration(
                                                      hintText:
                                                          '课程班号')),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context),
                                                child: const Text(
                                                    '取消')),
                                            FilledButton(
                                                onPressed: () {
                                                  _addConflictCourse(
                                                      i,
                                                      ctl.text
                                                          .trim());
                                                  Navigator.pop(
                                                      context);
                                                },
                                                child: const Text(
                                                    '添加')),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Text('+ 添加冲突',
                                        style:
                                            TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
