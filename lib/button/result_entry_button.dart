import 'package:flutter/material.dart';
import 'package:login_app/ResultsEntryScreen.dart';

/// Универсальная кнопка «Внести результаты» / «Редактировать результаты».
/// Показывается участнику, когда есть трассы и разрешено редактирование.
class ResultEntryButton extends StatelessWidget {
  final int eventId;
  final bool isParticipantActive;
  final bool isAccessUserEditResult;
  final bool isRoutesExists;
  final Future<void> Function() onResultSubmitted;

  const ResultEntryButton({
    super.key,
    required this.eventId,
    required this.isParticipantActive,
    required this.isAccessUserEditResult,
    required this.onResultSubmitted,
    this.isRoutesExists = true,
  });

  bool get _canEdit =>
      isParticipantActive && isAccessUserEditResult && isRoutesExists;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton(
        onPressed: _canEdit
            ? () async {
                final bool? needRefresh = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultEntryPage(
                      eventId: eventId,
                      isParticipantActive: isParticipantActive,
                    ),
                  ),
                );
                if (needRefresh == true) {
                  await onResultSubmitted();
                }
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          _canEdit ? 'Внести результаты' : 'Результаты добавлены',
          style: TextStyle(
            color: _canEdit ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
