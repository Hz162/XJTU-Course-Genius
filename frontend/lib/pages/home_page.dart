import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/course.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sidebar.dart';
import '../widgets/window_bar.dart';

class HomePage extends StatefulWidget {
  final ApiService api;
  final String initialCampus;
  const HomePage({super.key, required this.api, this.initialCampus = ''});

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
  List<Map<String, String>> _volunteerSlots = [];

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
    _currentCampus = widget.initialCampus;
    _loadConfig();
    _loadCampus();
    _loadCourseData('selected');
    _loadVolunteerSlots();
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
        const SnackBar(
            content: Text('配置已保存'),
            duration: Duration(seconds: 1),
            backgroundColor: successColor),
      );
    }
  }

  Future<void> _loadCampus() async {
    try {
      final list = await api.getCampusList();
      if (mounted) setState(() => _campusList = list);
    } catch (_) {}
  }

  Future<void> _loadVolunteerSlots() async {
    try {
      final slots = await api.getVolunteerSlots();
      if (mounted) setState(() => _volunteerSlots = slots);
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
      _handleApiError(e);
    }
  }

  Future<void> _addToWishList(Map<String, dynamic> item) async {
    // Pick volunteer slot if available
    String? cv;
    if (_volunteerSlots.isNotEmpty) {
      // Ask server which slots this specific course can use (原网页逻辑)
      final courseId = (item['teachingClassId'] ?? '').toString();
      final classType = (item['classType'] ?? _currentView).toString();
      final allowedSlots = await api.checkVolunteerSlots(courseId, classType, _currentCampus);
      if (!mounted) return;
      final available = _volunteerSlots.where((s) => allowedSlots.contains(s['grade'])).toList();

      cv = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.flag_rounded, size: 20, color: primaryColor),
            SizedBox(width: 8),
            Text('选择志愿', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          content: SizedBox(
            width: 240,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: available.isEmpty
                  ? [const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('无可选志愿槽位', style: TextStyle(color: textMuted)))]
                  : available.map((s) => InkWell(
                        onTap: () => Navigator.pop(ctx, s['grade']),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          child: Row(children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: primaryColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(child: Text(s['grade'] ?? '?',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primaryColor))),
                            ),
                            const SizedBox(width: 12),
                            Text(s['name'] ?? '',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      )).toList(),
            ),
          ),
        ),
      );
    }

    // User dismissed volunteer dialog without picking → don't add
    if (_volunteerSlots.isNotEmpty && cv == null) return;

    final entry = [
      (item['teachingClassId'] ?? '').toString(),
      (item['courseName'] ?? '').toString(),
      (item['teacherName'] ?? '').toString(),
      (item['teachingPlace'] ?? '').toString(),
      (item['classType'] ?? _currentView).toString(),
      _currentCampus,
      cv ?? '', // volunteer index
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

  void _addConflictCourse(int wishIdx, String courseId) {
    if (courseId.isEmpty || wishIdx >= _delCourses.length) return;
    setState(() {
      _delCourses[wishIdx].add(courseId);
      _delCourses[wishIdx] = _delCourses[wishIdx].toSet().toList();
    });
    _saveConfig();
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
      if (_volunteerSlots.isEmpty) _loadVolunteerSlots();
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg, style: const TextStyle(color: Colors.white)),
          backgroundColor: dangerColor),
    );
  }

  /// Handle API errors — redirects to login on session expiry.
  void _handleApiError(Object e) {
    if (e is SessionExpiredException) {
      redirectToLogin();
      return;
    }
    _showError(e.toString().replaceFirst('Exception: ', ''));
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
      if (_currentItem != SidebarItem.selection &&
          _currentItem != SidebarItem.config) {
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

  // ── Conflict course picker dialog ──

  Future<void> _showConflictPicker(int wishIdx) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return _ConflictPickerDialog(api: api);
      },
    );
    if (result != null && mounted) {
      _addConflictCourse(wishIdx, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleGlobalKey,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
            WindowBar(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                        _sidebarCollapsed
                            ? Icons.menu_rounded
                            : Icons.menu_open_rounded,
                        size: 20),
                    onPressed: () =>
                        setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  ),
                  const Text('XJTU Course Genius',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary)),
                  if (_selecting)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: shadowSm(primaryColor),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 6),
                            Text('抢课中',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Sidebar(
                    selected: _currentItem,
                    campus: _currentCampus,
                    collapsed: _sidebarCollapsed,
                    campusItems: _campusList.map<DropdownMenuItem<String>>((c) {
                      final code = c['code']?.toString() ?? '';
                      final name = c['name']?.toString() ?? '';
                      final selected = code == _currentCampus;
                      return DropdownMenuItem<String>(
                        value: code,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? primaryColor.withAlpha(25)
                                      : surfaceSecondary,
                                  borderRadius:
                                      BorderRadius.circular(radiusSm),
                                ),
                                child: Icon(Icons.location_on_rounded,
                                    size: 15,
                                    color: selected
                                        ? primaryColor
                                        : textMuted),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(name,
                                    style: TextStyle(
                                      fontSize: 13,
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
                                    size: 18, color: primaryColor),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    campusNames: _campusList
                        .map<String>((c) => c['name']?.toString() ?? '')
                        .toList(),
                    onItemSelected: _onSidebarItem,
                    onCampusChanged: _setCampus,
                  ),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
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

  // ─── Course Browser ───

  Widget _buildCoursePanel() {
    final accent = accentForType(_currentView);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          _buildSearchBar(accent),
          const SizedBox(height: 14),
          Expanded(child: _buildCourseTable(accent)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color accent) {
    if (_currentView == 'selected') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: borderColor),
        boxShadow: shadowSm(Colors.black),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search_rounded, color: textMuted, size: 20),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _keywordCtl,
              decoration: const InputDecoration(
                hintText: '搜索课程名称或教师...',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14, color: textPrimary),
              onChanged: (v) => _keyword = v,
              onSubmitted: (_) => _loadCourseData(_currentView),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: primaryGradient,
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(radiusMd),
              onTap: () => _loadCourseData(_currentView),
              child: const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Icon(Icons.search_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildCourseTable(Color accent) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tableData.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: textMuted.withAlpha(80)),
            const SizedBox(height: 12),
            const Text('暂无数据',
                style: TextStyle(fontSize: 14, color: textMuted)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _tableData.length,
      itemBuilder: (_, i) {
        final item = _tableData[i];
        final id = (item['teachingClassId'] ?? '').toString();
        final name = (item['courseName'] ?? '').toString();
        final teacher = (item['teacherName'] ?? '').toString();
        final place = (item['teachingPlace'] ?? '').toString();
        final type = (item['classType'] ?? '').toString();
        final typeName = (item['courseTypeName'] ?? '').toString();
        final courseAccent = type.isNotEmpty ? accentForType(type) : accent;
        final inWish = _wishList.any((e) => e.isNotEmpty && e[0] == id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(radiusLg),
              border: Border.all(color: borderColor),
              boxShadow: shadowSm(Colors.black),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(radiusLg),
              child: InkWell(
                borderRadius: BorderRadius.circular(radiusLg),
                onTap: () => _showCourseDetail(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 36,
                    decoration: BoxDecoration(
                      color: courseAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                size: 13, color: textMuted),
                            const SizedBox(width: 3),
                            Text(teacher,
                                style: const TextStyle(
                                    fontSize: 12, color: textSecondary)),
                            const SizedBox(width: 14),
                            const Icon(Icons.location_on_outlined,
                                size: 13, color: textMuted),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(place,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, color: textSecondary)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_currentView == 'selected') ...[
                    if (type.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: courseAccent.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(typeName.isNotEmpty ? typeName : _typeLabel(type),
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: courseAccent)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: dangerColor),
                      tooltip: '退课',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => _confirmDropCourse(item),
                    ),
                  ] else if (inWish)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: successColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(radiusSm),
                      ),
                      child: const Text('已添加',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: successColor)),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: primaryGradient,
                        borderRadius: BorderRadius.circular(radiusMd),
                        boxShadow: shadowSm(primaryColor),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(radiusMd),
                        onTap: () => _addToWishList(item),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          child: Text('+ 抢课',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        ),
      );
      },
    );
  }

  // ─── Selection Panel ───

  Widget _buildSelectionPanel() {
    final s = _selStatus;
    final total = _wishList.isNotEmpty ? _wishList.length : (s?.totalCourse ?? 0);
    final progress = s?.progress ?? 0;
    final doneCount = progress.clamp(0, total);
    final ratio = total > 0 ? doneCount / total : 0.0;

    final logs = _buildLogs(s);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(radiusXl),
              border: Border.all(color: borderColor),
              boxShadow: shadowMd(Colors.black),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: _selecting ? accentGradient : primaryGradient,
                    boxShadow: shadowMd(
                        _selecting ? accentPurple : primaryColor),
                  ),
                  child: Icon(
                    _selecting
                        ? Icons.sync_rounded
                        : Icons.rocket_launch_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(_selecting ? '抢课进行中...' : '准备就绪',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textPrimary)),
                if (s != null) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: borderColor,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(successColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statChip('$doneCount / $total', '课程进度'),
                      const SizedBox(width: 12),
                      _statChip('${(ratio * 100).toInt()}%', '完成率'),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: 200,
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: _selecting
                          ? const LinearGradient(
                              colors: [dangerColor, Color(0xFFDC2626)])
                          : primaryGradient,
                      boxShadow:
                          shadowMd(_selecting ? dangerColor : primaryColor),
                    ),
                    child: FilledButton(
                      onPressed: _toggleSelection,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              _selecting
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              size: 26),
                          const SizedBox(width: 8),
                          Text(_selecting ? '停 止' : '开 始',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_wishList.isNotEmpty && _selecting) ...[
            const SizedBox(height: 20),
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(radiusLg),
                border: Border.all(color: borderColor),
                boxShadow: shadowSm(Colors.black),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('待抢课程 · $doneCount/$total',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary)),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _wishList.length,
                      itemBuilder: (_, i) => _buildWishStatusItem(i, s),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_selecting && logs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(radiusLg),
                border: Border.all(color: borderColor),
                boxShadow: shadowSm(Colors.black),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('日志',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary)),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: logs.length,
                      itemBuilder: (_, i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(logs[i],
                              style: const TextStyle(
                                  fontSize: 12.5, color: textSecondary)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<String> _buildLogs(SelectionStatus? s) {
    if (s == null || _wishList.isEmpty) return [];
    // Use real server logs from backend, fall back to generated summary
    if (s.log.isNotEmpty) {
      return s.log;
    }
    final logs = <String>['开始抢课'];
    return logs;
  }

  Widget _buildWishStatusItem(int i, SelectionStatus? s) {
    final c = _wishList[i];
    final done = s != null && i < s.flags.length && s.flags[i] == 1;
    final active = !done && (s?.running ?? false);
    final borderClr = done
        ? successColor.withAlpha(40)
        : active
            ? primaryColor.withAlpha(50)
            : borderColor;
    final bgClr = done
        ? successColor.withAlpha(25)
        : active
            ? primaryColor.withAlpha(25)
            : surfaceSecondary;
    final statusText = done
        ? '已抢到 ✓'
        : (active ? '抢课中...' : '等待中');
    final statusColor =
        done ? successColor : (active ? primaryColor : textMuted);
    final name =
        c.length > 1 ? c[1] : (c.isNotEmpty ? c[0] : '?');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: borderClr, width: active ? 1.5 : 0.5),
        boxShadow: active ? shadowSm(primaryColor) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radiusSm),
              color: bgClr,
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check_rounded,
                      size: 18, color: successColor)
                  : active
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: primaryColor))
                      : Text('${i + 1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textMuted)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: done ? textSecondary : textPrimary)),
                const SizedBox(height: 2),
                Text(statusText,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceSecondary,
        borderRadius: BorderRadius.circular(radiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary)),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: textSecondary)),
        ],
      ),
    );
  }

  // ─── Config Panel ───

  Widget _buildConfigPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('抢课配置',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textPrimary)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _loadConfig,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('读取'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saveConfig,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('保存'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_wishList.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 32),
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(radiusXl),
                border: Border.all(color: borderColor),
                boxShadow: shadowSm(Colors.black),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_add_outlined,
                      size: 48, color: textMuted.withAlpha(100)),
                  const SizedBox(height: 12),
                  const Text('暂无课程',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textSecondary)),
                  const SizedBox(height: 4),
                  const Text('在课程浏览页面点击"+"添加需要抢课的课程',
                      style: TextStyle(fontSize: 13, color: textMuted)),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _wishList.length,
                itemBuilder: (_, i) => _buildWishCard(i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWishCard(int i) {
    final c = _wishList[i];
    final conflicts =
        i < _delCourses.length ? _delCourses[i] : <String>[];
    final id = c.isNotEmpty ? c[0] : '?';
    final name = c.length > 1 ? c[1] : '?';
    final teacher = c.length > 2 ? c[2] : '';
    final place = c.length > 3 ? c[3] : '';
    final type = c.length > 4 ? c[4] : '';
    final cv = c.length > 6 ? c[6] : '';
    final accent = accentForType(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: borderColor),
        boxShadow: shadowSm(Colors.black),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withAlpha(25),
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          child: Center(
            child: Text('${i + 1}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accent)),
          ),
        ),
        title: Text(name,
            style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: textPrimary)),
        subtitle: Row(
          children: [
            if (teacher.isNotEmpty) ...[
              Text(teacher,
                  style: const TextStyle(
                      fontSize: 11.5, color: textSecondary)),
              const SizedBox(width: 10),
            ],
            if (place.isNotEmpty)
              Expanded(
                child: Text(place,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: textMuted)),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (conflicts.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: warningColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(radiusSm),
                ),
                child: Text('${conflicts.length}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: warningColor)),
              ),
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(radiusSm),
              onTap: () => _showDeleteConfirm(i, name),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.delete_outline_rounded,
                    color: dangerColor, size: 20),
              ),
            ),
          ],
        ),
        children: [
          Row(
            children: [
              const Icon(Icons.tag, size: 14, color: textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(id,
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                        color: textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Volunteer slot selector (only for 预选 rounds)
          if (_volunteerSlots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _volunteerSlots.any((s) => s['grade'] == cv) ? cv : _volunteerSlots.first['grade'],
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: '志愿',
                  prefixIcon: const Icon(Icons.flag_rounded, color: primaryColor, size: 18),
                  filled: true,
                  fillColor: surfaceSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(radiusMd),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(radiusMd),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(radiusMd),
                    borderSide: const BorderSide(color: primaryColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                icon: const Icon(Icons.expand_more_rounded, color: textSecondary),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
                items: _volunteerSlots.map((s) => DropdownMenuItem(
                  value: s['grade'] ?? '',
                  child: Text(s['name'] ?? '',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                )).toList(),
                onChanged: (v) => setState(() {
                  while (_wishList[i].length <= 6) { _wishList[i].add(''); }
                  _wishList[i][6] = v ?? '';
                }),
              ),
            ),
          if (conflicts.isNotEmpty) ...[
            const Text('冲突课程',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textPrimary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: conflicts.map((cid) {
                return Container(
                  padding: const EdgeInsets.only(left: 10, right: 2),
                  decoration: BoxDecoration(
                    color: dangerColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(radiusSm),
                    border: Border.all(
                        color: dangerColor.withAlpha(40)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cid,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              color: dangerColor)),
                      InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () =>
                            _removeConflictCourse(i, cid),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded,
                              size: 14, color: dangerColor),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showConflictPicker(i),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('添加冲突课程',
                  style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: textSecondary,
                side: const BorderSide(
                    color: borderColor, style: BorderStyle.solid),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radiusMd)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    const labels = {
      'TJKC': '主修', 'FANKC': '方案内', 'FAWKC': '方案外',
      'XGXK': '通识', 'TYKC': '体育',
    };
    return labels[type] ?? type;
  }

  void _showCourseDetail(Map<String, dynamic> item) {
    final id = (item['teachingClassId'] ?? '').toString();
    final name = (item['courseName'] ?? '').toString();
    final teacher = (item['teacherName'] ?? '').toString();
    final place = (item['teachingPlace'] ?? '').toString();
    final type = (item['classType'] ?? '').toString();
    final typeName = (item['courseTypeName'] ?? '').toString();
    final accent = accentForType(type);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXl)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(25),
                      borderRadius: BorderRadius.circular(radiusMd),
                    ),
                    child: Icon(Icons.school_rounded, color: accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                                fontFamily: 'NotoSansSC')),
                        if (type.isNotEmpty)
                          Text((typeName.isNotEmpty ? typeName : _typeLabel(type)),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: accent)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 22),
                    splashRadius: 16,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _detailRow('课程班号', id),
              _detailRow('授课教师', teacher),
              _detailRow('上课地点', place),
              _detailRow('课程类别', (typeName.isNotEmpty ? typeName : _typeLabel(type))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('关闭'),
                    ),
                  ),
                  if (_currentView != 'selected') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _addToWishList(item);
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('加入抢课'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: textMuted,
                    fontFamily: 'NotoSansSC')),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                    fontFamily: 'NotoSansSC')),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDropCourse(Map<String, dynamic> item) async {
    final name = (item['courseName'] ?? '').toString();
    final id = (item['teachingClassId'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退课'),
        content: Text('确定要退选「$name」($id) 吗？\n此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: dangerColor),
            child: const Text('确认退课'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await api.dropCourse(id);
      _showError('退课成功');
      // Refresh selected courses
      _loadCourseData('selected');
    } catch (e) {
      if (e is SessionExpiredException) { redirectToLogin(); return; }
      _showError('退课失败: ${e.toString().replaceFirst("Exception: ", "")}');
    }
  }

  void _showDeleteConfirm(int i, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除抢课项'),
        content: Text('确定要将「$name」从抢课列表中移除吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeWishItem(i);
            },
            style: FilledButton.styleFrom(
                backgroundColor: dangerColor),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }
}

// ─── Conflict Picker Dialog ───

class _ConflictPickerDialog extends StatefulWidget {
  final ApiService api;

  const _ConflictPickerDialog({required this.api});

  @override
  State<_ConflictPickerDialog> createState() => _ConflictPickerDialogState();
}

class _ConflictPickerDialogState extends State<_ConflictPickerDialog> {
  final _ctl = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final kw = _ctl.text.trim();
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final result = await widget.api
          .queryCourses('all', keyword: kw);
      if (!mounted) return;
      setState(() {
        _results = (result['courses'] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl)),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 540),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('搜索冲突课程',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textPrimary)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 22),
                  splashRadius: 16,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '输入课程名称或教师名搜索...',
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 20, color: textMuted),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14)),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Text('搜索'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Manual entry as fallback
            Row(
              children: [
                const Icon(Icons.edit_note_rounded,
                    size: 16, color: textMuted),
                const SizedBox(width: 6),
                const Text('或直接输入班号:',
                    style:
                        TextStyle(fontSize: 12, color: textMuted)),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '粘贴课程班编号',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace'),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) {
                          Navigator.pop(context, v.trim());
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_searched && _results.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off_rounded,
                        size: 40, color: textMuted.withAlpha(80)),
                    const SizedBox(height: 8),
                    const Text('未找到匹配课程',
                        style: TextStyle(
                            fontSize: 13, color: textMuted)),
                  ],
                ),
              )
            else if (_results.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final item = _results[i];
                    final cid =
                        (item['teachingClassId'] ?? '').toString();
                    final cname =
                        (item['courseName'] ?? '').toString();
                    final cteacher =
                        (item['teacherName'] ?? '').toString();
                    final cplace =
                        (item['teachingPlace'] ?? '').toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: surfaceSecondary,
                        borderRadius:
                            BorderRadius.circular(radiusMd),
                        border: Border.all(color: borderLight),
                      ),
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(radiusMd),
                        onTap: () =>
                            Navigator.pop(context, cid),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(cname,
                                        style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight:
                                                FontWeight.w600,
                                            color: textPrimary)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(cteacher,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    textMuted)),
                                        const SizedBox(width: 8),
                                        if (cplace.isNotEmpty)
                                          Text(cplace,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      textMuted)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(cid,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily:
                                                'monospace',
                                            color: textSecondary)),
                                  ],
                                ),
                              ),
                              const Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 22,
                                  color: primaryColor),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
