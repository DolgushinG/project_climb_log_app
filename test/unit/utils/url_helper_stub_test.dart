import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/utils/url_helper_stub.dart' as stub;

void main() {
  group('url_helper_stub', () {
    test('currentPageUri returns null', () {
      expect(stub.currentPageUri, isNull);
    });

    test('clearTokenFromUrl does not throw', () {
      expect(() => stub.clearTokenFromUrl(), returnsNormally);
    });
  });
}
