import 'package:flutter_test/flutter_test.dart';
import 'package:schooldrop/features/account/password_fields.dart';

void main() {
  test('password rules: length, upper, lower, number and symbol', () {
    expect(PasswordRules.isStrong('Passw0rd-123'), isTrue);
    expect(PasswordRules.isStrong('password123'), isFalse); // no uppercase, no symbol
    expect(PasswordRules.isStrong('PASSWORD-123'), isFalse); // no lowercase
    expect(PasswordRules.isStrong('Pa-1'), isFalse); // too short
    expect(PasswordRules.validate('Passw0rd'), contains('symbol'));
    expect(PasswordRules.validate('Passw0rd!'), isNull);
  });
}
