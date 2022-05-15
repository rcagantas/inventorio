
import 'package:flutter_test/flutter_test.dart';
import 'package:inventorio/core/models/app_user.dart';

void main() {
  test('should fail to build user if invalid', () async {
    AppUser user = AppUser(knownInventories: null, userId: null, currentInventoryId: null, currentVersion: null);
    AppUserBuilder builder = AppUserBuilder.fromAppUser(user);
    expect(() => builder.build(), throwsException);
  });
}