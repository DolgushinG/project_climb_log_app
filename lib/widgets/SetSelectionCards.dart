import 'package:flutter/material.dart';
import 'package:login_app/models/NumberSets.dart';
import 'package:login_app/theme/app_theme.dart';
import 'package:login_app/utils/display_helper.dart';

/// Карточки сетов для выбора: номер, дата, N/M мест.
/// Выбранная карточка — выделенная обводка (AppColors.mutedGold).
/// При нажатии карточка расширяется, показывая полную информацию.
class SetSelectionCards extends StatefulWidget {
  final List<NumberSets> sets;
  final NumberSets? selected;
  final ValueChanged<NumberSets?> onChanged;

  const SetSelectionCards({
    super.key,
    required this.sets,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<SetSelectionCards> createState() => _SetSelectionCardsState();
}

class _SetSelectionCardsState extends State<SetSelectionCards> {
  int? _expandedId;

  @override
  Widget build(BuildContext context) {
    if (widget.sets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Нет доступных сетов',
          style: unbounded(fontSize: 14, color: Colors.white54),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final spacing = 8.0;
        final count = w < 320 ? 2 : (w < 400 ? 3 : 4);
        final itemW = (w - spacing * (count - 1)) / count;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: widget.sets.map((s) {
            final isSelected = widget.selected?.id == s.id;
            final isExpanded = _expandedId == s.id;
            return SizedBox(
              width: isExpanded ? w : itemW,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedId = null;
                    } else {
                      _expandedId = s.id;
                      if (!isSelected) widget.onChanged(s);
                    }
                  });
                },
                child: _SetCard(
                  set: s,
                  isSelected: isSelected,
                  isExpanded: isExpanded,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SetCard extends StatelessWidget {
  final NumberSets set;
  final bool isSelected;
  final bool isExpanded;

  const _SetCard({
    required this.set,
    required this.isSelected,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final occupied = set.participants_count;
    final total = set.max_participants;
    final free = set.free;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isExpanded ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.rowAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.mutedGold : AppColors.graphite,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Сет ${set.number_set}',
                style: unbounded(
                  fontSize: isExpanded ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.mutedGold : Colors.white,
                ),
              ),
              if (isExpanded) ...[
                const Spacer(),
                Icon(
                  isSelected ? Icons.check_circle : Icons.touch_app_outlined,
                  size: 20,
                  color: isSelected ? AppColors.mutedGold : Colors.white54,
                ),
              ],
            ],
          ),
          if (set.day_of_week.trim().isNotEmpty || set.time.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              formatSetCompact(set),
              style: unbounded(
                fontSize: isExpanded ? 14 : 12,
                color: Colors.white70,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: isExpanded ? 2 : 1,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.group_outlined,
                size: isExpanded ? 16 : 14,
                color: Colors.white54,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$occupied/$total мест',
                  style: unbounded(
                    fontSize: isExpanded ? 14 : 12,
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 8),
            Text(
              'Свободно мест: $free',
              style: unbounded(fontSize: 13, color: Colors.white60),
            ),
            if (set.allow_years_from != null || set.allow_years_to != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatAgeRestriction(set.allow_years_from, set.allow_years_to),
                style: unbounded(fontSize: 12, color: Colors.white54),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _formatAgeRestriction(int? from, int? to) {
    if (from != null && to != null) return 'Возраст: год рождения $from–$to';
    if (from != null) return 'Возраст: год рождения от $from';
    if (to != null) return 'Возраст: год рождения до $to';
    return '';
  }
}
