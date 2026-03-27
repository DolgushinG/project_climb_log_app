import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/utils/competition_detail_button_logic.dart';

void main() {
  group('CompetitionDetailButtonLogic', () {
    group('canShowResultButton', () {
      test('не показывать когда не участник', () {
        expect(
          CompetitionDetailButtonLogic.canShowResultButton(
            isParticipant: false,
            paymentConfirmed: true,
            sendResultState: true,
            resultExists: false,
            editAllowed: true,
          ),
          isFalse,
        );
      });

      test('не показывать когда оплата не подтверждена (платное, не оплачено)', () {
        expect(
          CompetitionDetailButtonLogic.canShowResultButton(
            isParticipant: true,
            paymentConfirmed: false,
            sendResultState: true,
            resultExists: false,
            editAllowed: true,
          ),
          isFalse,
        );
      });

      test('не показывать когда !is_send_result_state', () {
        expect(
          CompetitionDetailButtonLogic.canShowResultButton(
            isParticipant: true,
            paymentConfirmed: true,
            sendResultState: false,
            resultExists: false,
            editAllowed: true,
          ),
          isFalse,
        );
      });

      test('показывать «Внести»: участник, оплата ок, send_result_state, нет результата', () {
        expect(
          CompetitionDetailButtonLogic.canShowResultButton(
            isParticipant: true,
            paymentConfirmed: true,
            sendResultState: true,
            resultExists: false,
            editAllowed: false,
          ),
          isTrue,
        );
      });

      test('показывать «Обновить»: результат есть + editAllowed', () {
        expect(
          CompetitionDetailButtonLogic.canShowResultButton(
            isParticipant: true,
            paymentConfirmed: true,
            sendResultState: true,
            resultExists: true,
            editAllowed: true,
          ),
          isTrue,
        );
      });

      test('не показывать когда результат есть но !editAllowed', () {
        expect(
          CompetitionDetailButtonLogic.canShowResultButton(
            isParticipant: true,
            paymentConfirmed: true,
            sendResultState: true,
            resultExists: true,
            editAllowed: false,
          ),
          isFalse,
        );
      });

      test('бесплатное: paymentConfirmed=true', () {
        expect(
          CompetitionDetailButtonLogic.canShowResultButton(
            isParticipant: true,
            paymentConfirmed: true,
            sendResultState: true,
            resultExists: false,
            editAllowed: false,
          ),
          isTrue,
        );
      });
    });

    group('resultButtonCanEdit', () {
      test('нет результата → можно вносить (editAllowed не нужен)', () {
        expect(
          CompetitionDetailButtonLogic.resultButtonCanEdit(
            resultExists: false,
            editAllowed: false,
            routesExists: true,
          ),
          isTrue,
        );
      });

      test('есть результат + editAllowed → можно обновлять', () {
        expect(
          CompetitionDetailButtonLogic.resultButtonCanEdit(
            resultExists: true,
            editAllowed: true,
            routesExists: true,
          ),
          isTrue,
        );
      });

      test('есть результат + !editAllowed → нельзя', () {
        expect(
          CompetitionDetailButtonLogic.resultButtonCanEdit(
            resultExists: true,
            editAllowed: false,
            routesExists: true,
          ),
          isFalse,
        );
      });

      test('нет трасс → нельзя', () {
        expect(
          CompetitionDetailButtonLogic.resultButtonCanEdit(
            resultExists: false,
            editAllowed: true,
            routesExists: false,
          ),
          isFalse,
        );
      });
    });

    group('canShowCancelRegistrationButton', () {
      test('показывать когда можно отменить и нет результата', () {
        expect(
          CompetitionDetailButtonLogic.canShowCancelRegistrationButton(
            isAccessUserCancelTakePart: 1,
            isParticipantPaid: false,
            resultExists: false,
          ),
          isTrue,
        );
      });

      test('НЕ показывать после внесения результатов', () {
        expect(
          CompetitionDetailButtonLogic.canShowCancelRegistrationButton(
            isAccessUserCancelTakePart: 1,
            isParticipantPaid: false,
            resultExists: true,
          ),
          isFalse,
        );
      });

      test('НЕ показывать когда уже оплачено (для платных)', () {
        expect(
          CompetitionDetailButtonLogic.canShowCancelRegistrationButton(
            isAccessUserCancelTakePart: 1,
            isParticipantPaid: true,
            resultExists: false,
          ),
          isFalse,
        );
      });

      test('НЕ показывать когда is_access_user_cancel_take_part != 1', () {
        expect(
          CompetitionDetailButtonLogic.canShowCancelRegistrationButton(
            isAccessUserCancelTakePart: 0,
            isParticipantPaid: false,
            resultExists: false,
          ),
          isFalse,
        );
      });

      test('НЕ показывать когда has_bill (чек прикреплён) — единая логика с backend', () {
        expect(
          CompetitionDetailButtonLogic.canShowCancelRegistrationButton(
            isAccessUserCancelTakePart: 1,
            isParticipantPaid: false,
            resultExists: false,
            hasBill: true,
          ),
          isFalse,
        );
      });

      test('НЕ показывать когда has_payment (онлайн-оплата)', () {
        expect(
          CompetitionDetailButtonLogic.canShowCancelRegistrationButton(
            isAccessUserCancelTakePart: 1,
            isParticipantPaid: false,
            resultExists: false,
            hasPayment: true,
          ),
          isFalse,
        );
      });
    });

    group('isPaymentConfirmed', () {
      test('бесплатное → true', () {
        expect(
          CompetitionDetailButtonLogic.isPaymentConfirmed(
            isNeedPayForReg: false,
            isParticipantPaid: false,
          ),
          isTrue,
        );
      });

      test('платное + оплачено → true', () {
        expect(
          CompetitionDetailButtonLogic.isPaymentConfirmed(
            isNeedPayForReg: true,
            isParticipantPaid: true,
          ),
          isTrue,
        );
      });

      test('платное + не оплачено → false', () {
        expect(
          CompetitionDetailButtonLogic.isPaymentConfirmed(
            isNeedPayForReg: true,
            isParticipantPaid: false,
          ),
          isFalse,
        );
      });
    });
  });
}
