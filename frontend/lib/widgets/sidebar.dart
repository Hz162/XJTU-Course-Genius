import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
  final List<String> campusNames;
  final bool collapsed;

  const Sidebar({
    super.key,
    required this.selected,
    required this.campus,
    required this.campusItems,
    required this.campusNames,
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
    if (widget.collapsed) return const SizedBox.shrink();
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: surfaceColor,
        border: Border(right: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildSection('课程浏览', [
            _item(SidebarItem.selected, '已选课程', Icons.checklist_rounded, primaryColor),
            _item(SidebarItem.tjkc, '主修推荐', Icons.auto_awesome, primaryColor),
            _item(SidebarItem.fankc, '方案内', Icons.swap_horiz_rounded, successColor),
            _item(SidebarItem.fawkc, '方案外', Icons.open_in_new_rounded, warningColor),
            _item(SidebarItem.xgxk, '基础通识', Icons.public_rounded, accentPurple),
            _item(SidebarItem.tykc, '体育', Icons.fitness_center_rounded, accentTeal),
          ]),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(),
          ),
          const SizedBox(height: 8),
          _buildSection('操作', [
            _item(SidebarItem.selection, '选课控制', Icons.rocket_launch_rounded, accentPink),
            _item(SidebarItem.config, '配置管理', Icons.tune_rounded, textSecondary),
          ]),
          const Spacer(),
          _buildCampusChip(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                  letterSpacing: 1.2)),
        ),
        ...items,
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _item(SidebarItem item, String label, IconData icon, Color accent) {
    final active = widget.selected == item;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: active ? accent.withAlpha(20) : Colors.transparent,
        borderRadius: BorderRadius.circular(radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(radiusMd),
          onTap: () => widget.onItemSelected(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: active
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(radiusMd),
                    border: Border(left: BorderSide(color: accent, width: 3)),
                  )
                : null,
            child: Row(
              children: [
                Icon(icon,
                    size: 19,
                    color: active ? accent : textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? textPrimary : textSecondary,
                      )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampusChip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: surfaceSecondary,
          borderRadius: BorderRadius.circular(radiusMd),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded,
                size: 17, color: textMuted),
            const SizedBox(width: 6),
            const Text('校区',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: textSecondary)),
            const SizedBox(width: 6),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.campus.isNotEmpty ? widget.campus : null,
                  isExpanded: true,
                  isDense: true,
                  padding: EdgeInsets.zero,
                  selectedItemBuilder: (ctx) {
                    return widget.campusNames.map((name) {
                      return Container(
                        alignment: Alignment.centerLeft,
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                              fontFamily: 'NotoSansSC',
                            )),
                      );
                    }).toList();
                  },
                icon: const Icon(Icons.expand_more_rounded,
                      size: 18, color: textMuted),
                  borderRadius: BorderRadius.circular(radiusMd),
                  menuMaxHeight: 280,
                  hint: const Text('选择',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: textMuted,
                          fontFamily: 'NotoSansSC')),
                  items: widget.campusItems,
                  onChanged: (v) {
                    if (v != null) widget.onCampusChanged(v);
                  },
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                      fontFamily: 'NotoSansSC'),
                  dropdownColor: surfaceColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
