import 'package:flutter/material.dart';

enum SidebarItem {
  selected,
  tjkc,
  fankc,
  fawkc,
  xgxk,
  tykc,
  selection,
  config,
}

class Sidebar extends StatefulWidget {
  final SidebarItem selected;
  final String campus;
  final List<DropdownMenuItem<String>> campusItems;
  final ValueChanged<SidebarItem> onItemSelected;
  final ValueChanged<String> onCampusChanged;
  final bool collapsed;

  const Sidebar({
    super.key,
    required this.selected,
    required this.campus,
    required this.campusItems,
    required this.onItemSelected,
    required this.onCampusChanged,
    this.collapsed = false,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.collapsed ? 0 : 200,
      color: Colors.white,
      child: Column(
        children: [
          _buildSection('课程浏览', [
            _item(SidebarItem.selected, '已选课程', Icons.list_alt),
            _item(SidebarItem.tjkc, '主修推荐', Icons.star_outline),
            _item(SidebarItem.fankc, '方案内', Icons.swap_horiz),
            _item(SidebarItem.fawkc, '方案外', Icons.open_in_new),
            _item(SidebarItem.xgxk, '基础通识', Icons.public),
            _item(SidebarItem.tykc, '体育', Icons.sports_soccer),
          ]),
          const Divider(height: 1),
          _buildSection('操作', [
            _item(SidebarItem.selection, '选课控制', Icons.play_circle_outline),
            _item(SidebarItem.config, '配置管理', Icons.settings),
          ]),
          const Spacer(),
          _buildCampusSelector(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(title, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: Color(0xFF909399), letterSpacing: 1,
            )),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _item(SidebarItem item, String label, IconData icon) {
    final active = widget.selected == item;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: active ? const Color(0xFFECF5FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onItemSelected(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: active
                    ? const Color(0xFF409EFF) : const Color(0xFF909399)),
                const SizedBox(width: 10),
                Text(label, style: TextStyle(
                  fontSize: 13,
                  color: active ? const Color(0xFF409EFF) : const Color(0xFF606266),
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampusSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Color(0xFF909399)),
            const SizedBox(width: 8),
            const Text('校区', style: TextStyle(fontSize: 12, color: Color(0xFF909399))),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.campus.isNotEmpty ? widget.campus : null,
                  isExpanded: true,
                  isDense: true,
                  hint: const Text('选择', style: TextStyle(fontSize: 12)),
                  items: widget.campusItems,
                  onChanged: (v) {
                    if (v != null) widget.onCampusChanged(v);
                  },
                  style: const TextStyle(fontSize: 12, color: Color(0xFF303133)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
