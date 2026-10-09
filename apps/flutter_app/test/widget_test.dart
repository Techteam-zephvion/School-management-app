import 'package:flutter_test/flutter_test.dart';
import 'package:schoolic/src/core/models.dart';

void main() {
  test('auth session serializes roles and dev identity', () {
    const session = AuthSession(
      email: 'admin@schoolic.local',
      roles: [AppRole.admin],
      schoolId: 'school-1',
      devNeonUserId: 'dev-admin',
    );

    final restored = AuthSession.fromJson(session.toJson());

    expect(restored.email, 'admin@schoolic.local');
    expect(restored.isAdmin, isTrue);
    expect(restored.devNeonUserId, 'dev-admin');
  });
}
