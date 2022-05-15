
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventorio/core/providers/auth_provider.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';
import 'package:inventorio/core/providers/user_provider.dart';

import '../../mocks.dart';

void main() {
  late ProviderContainer container;
  late TestScaffold t;

  setUp(() async {
    t = TestScaffold();
    await t.setUpFakeStore(t.store);
    container = ProviderContainer(overrides: [
      pluginsProvider.overrideWithValue(t.plugins),
      authProvider.overrideWithValue(AuthNotifier(t.mockUser, null)),
    ]);
  });

  test('should create a user given an auth uid', () async {
    await container.read(userStreamProvider.future);
    var user = container.read(userProvider);
    expect(user.userId, 'userId');
  });

  test('should return new user if new login', () async {
    t = TestScaffold();
    await t.setUpFakeStore(t.store);
    container = ProviderContainer(overrides: [
      pluginsProvider.overrideWithValue(t.plugins),
      authProvider.overrideWithValue(AuthNotifier(MockUser(uid: 'new_user'), null)),
    ]);

    await container.read(userStreamProvider.future);
    var user = container.read(userProvider);
    expect(user.userId, 'new_user');
  });
}