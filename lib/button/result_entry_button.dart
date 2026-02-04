import 'package:flutter/material.dart';
import 'package:login_app/ResultsEntryScreen.dart';

/// Универсальная кнопка «Внести результаты» / «Редактировать результаты».
/// Показывается участнику, когда есть трассы и разрешено редактирование.
class ResultEntryButton extends StatelessWidget {
  final int eventId;
  final bool isParticipantActive;
  final bool isAccessUserEditResult;
  final bool isOpenSendResultState;
  final bool isRoutesExists;
  final Future<void> Function() onResultSubmitted;

  const ResultEntryButton({
    super.key,
    required this.eventId,
    required this.isParticipantActive,
    required this.isAccessUserEditResult,
    required this.isOpenSendResultState,
    required this.onResultSubmitted,
    this.isRoutesExists = true,
  });

  /// Кнопка активна: до отправки — is_open_send_result_state; после — только is_access_user_edit_result
  bool get _canEdit =>
      (isParticipantActive ? isAccessUserEditResult : (isOpenSendResultState || isAccessUserEditResult)) &&
      isRoutesExists;

  String get _buttonText {
    if (!isParticipantActive) return 'Внести результаты';
    if (isAccessUserEditResult) return 'Обновить результаты';
    return 'Результаты добавлены';
  }

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
          backgroundColor: _canEdit ? const Color(0xFF16A34A) : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          _buttonText,
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
