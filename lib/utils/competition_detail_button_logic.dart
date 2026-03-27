/// Чистая логика показа кнопок на странице детали соревнования.
/// Все условия собраны здесь для единой точки истины и тестирования.
///
/// См. logic-details-page-competition.md
class CompetitionDetailButtonLogic {
  CompetitionDetailButtonLogic._();

  /// Показать кнопку «Внести/Обновить результаты».
  ///
  /// Условия:
  /// - участник, оплата подтверждена (или не требуется)
  /// - is_send_result_state == true
  /// - нет результата → «Внести»; есть результат + is_access_user_edit_result → «Обновить»
  /// - есть результат без editAllowed → не показывать
  static bool canShowResultButton({
    required bool isParticipant,
    required bool paymentConfirmed,
    required bool sendResultState,
    required bool resultExists,
    required bool editAllowed,
  }) {
    final baseOk = isParticipant && paymentConfirmed;
    return baseOk &&
        sendResultState &&
        (!resultExists || (resultExists && editAllowed));
  }

  /// Кнопка ResultEntryButton активна (можно нажать).
  ///
  /// - Нет результата → можно вносить
  /// - Есть результат → нужен is_access_user_edit_result
  static bool resultButtonCanEdit({
    required bool resultExists,
    required bool editAllowed,
    required bool routesExists,
  }) {
    return routesExists && (!resultExists || editAllowed);
  }

  /// Показать кнопку «Отменить регистрацию».
  ///
  /// Единая логика с backend (cancel_take_part.blade.php):
  /// - is_access_user_cancel_take_part == 1
  /// - !has_bill — после прикрепления чека отмена невозможна
  /// - !has_payment — после онлайн-оплаты (T‑Банк и т.д.) отмена невозможна
  /// - !is_participant_paid — после подтверждения оплаты отмена невозможна
  /// - !resultExists — после внесения результатов отмена невозможна никогда
  ///
  /// [hasBill] / [hasPayment] — из checkout API; при true кнопка не показывается.
  /// Для бесплатных событий и когда checkout не загружен — передать false или null.
  static bool canShowCancelRegistrationButton({
    required int isAccessUserCancelTakePart,
    required bool isParticipantPaid,
    required bool resultExists,
    bool? hasBill,
    bool? hasPayment,
  }) {
    return isAccessUserCancelTakePart == 1 &&
        !resultExists &&
        !isParticipantPaid &&
        (hasBill != true) &&
        (hasPayment != true);
  }

  /// Оплата подтверждена: для бесплатных — всегда true, для платных — isParticipantPaid.
  static bool isPaymentConfirmed({
    required bool isNeedPayForReg,
    required bool isParticipantPaid,
  }) {
    return !isNeedPayForReg || isParticipantPaid;
  }
}
