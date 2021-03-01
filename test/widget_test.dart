import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:inventorio/main.dart';
import 'package:inventorio/models/inv_auth.dart';
import 'package:inventorio/models/inv_item.dart';
import 'package:inventorio/models/inv_user.dart';
import 'package:inventorio/providers/inv_state.dart';
import 'package:inventorio/providers/user_state.dart';
import 'package:inventorio/services/inv_auth_service.dart';
import 'package:inventorio/services/inv_scheduler_service.dart';
import 'package:inventorio/services/inv_store_service.dart';
import 'package:mockito/mockito.dart';

import 'mocks.dart';

void main() {

  group('Inventory Repo', () {
    InvState invState;
    InvStoreServiceMock invStoreServiceMock;
    MockPluginsManager mockPluginsManager = MockPluginsManager();

    setUp(() {
      mockPluginsManager.setupDefaultMockValues();
      GetIt.instance.reset();
      GetIt.instance.registerSingleton<Clock>(ClockMock());
      GetIt.instance.registerLazySingleton<InvAuthService>(() => InvAuthServiceMock());
      GetIt.instance.registerLazySingleton<InvSchedulerService>(() => InvSchedulerServiceMock());
      GetIt.instance.registerLazySingleton<InvStoreService>(() => InvStoreServiceMock());
      GetIt.instance.registerLazySingleton(() => UserState());
      GetIt.instance.registerLazySingleton(() => InvState());

      invStoreServiceMock = GetIt.instance.get<InvStoreService>();
      when(invStoreServiceMock.listenToUser(any)).thenAnswer((realInvocation) => Stream.empty());
      when(invStoreServiceMock.migrateUserFromGoogleIdIfPossible(any)).thenAnswer((realInvocation) => Future.value());
      when(invStoreServiceMock.listenToInventoryList(any)).thenAnswer((realInvocation) => Stream.fromIterable([<InvItem>[]]));
      when(invStoreServiceMock.listenToInventoryMeta(any)).thenAnswer((realInvocation) => Stream.empty());

      invState = GetIt.instance.get<InvState>();
    });


    test('should create a new inventory and user on first log in', () async {
      // given
      String givenId = 'user_id';
      InvAuth invAuth = InvAuth(uid: givenId);

      // when
      when(invStoreServiceMock.listenToUser(any))
          .thenAnswer((realInvocation) => Stream.fromIterable([InvUser.unset(userId: 'user_id'),]));
      when(invStoreServiceMock.createNewUser(any))
          .thenReturn(InvUser(userId: givenId, currentInventoryId: 'inv_id', knownInventories: ['inv_id']));

      await invState.loadUserId(invAuth);

      // then
      verify(invStoreServiceMock.migrateUserFromGoogleIdIfPossible(invAuth)).called(1);
      verify(invStoreServiceMock.listenToUser(givenId)).called(1);
      verify(invStoreServiceMock.createNewUser(givenId)).called(1);
    });

    test('should load existing inventory when user has logged in', () async {
      // given
      String givenId = 'user_id';
      InvAuth invAuth = InvAuth(uid: givenId);

      // when
      when(invStoreServiceMock.listenToUser(any))
          .thenAnswer((realInvocation) => Stream.fromIterable([
            InvUser(
              userId: givenId,
              currentInventoryId: 'inv_id',
              knownInventories: ['inv_id']
            )
          ]));
      await invState.loadUserId(invAuth);

      // then
      verify(invStoreServiceMock.migrateUserFromGoogleIdIfPossible(invAuth)).called(1);
      verify(invStoreServiceMock.listenToUser(givenId)).called(1);
      verifyNever(invStoreServiceMock.createNewUser(givenId));
    });
  });

  group('Splash Screen', () {
    InvAuthServiceMock authServiceMock;
    MockPluginsManager mockPluginsManager = MockPluginsManager();

    setUp(() async {
      mockPluginsManager.setupDefaultMockValues();
      GetIt.instance.reset();
      GetIt.instance.registerSingleton<Clock>(ClockMock());
      GetIt.instance.registerLazySingleton<InvAuthService>(() => InvAuthServiceMock());
      GetIt.instance.registerLazySingleton<InvSchedulerService>(() => InvSchedulerServiceMock());
      GetIt.instance.registerLazySingleton<InvStoreService>(() => InvStoreServiceMock());
      GetIt.instance.registerLazySingleton(() => UserState());
      GetIt.instance.registerLazySingleton(() => InvState());

      authServiceMock = GetIt.instance<InvAuthService>();
      when(authServiceMock.onAuthStateChanged).thenAnswer((realInvocation) => Stream.fromIterable([]));
    });

    testWidgets('should show splash screen on entry', (tester) async {
      await tester.pumpWidget(MyApp());

      expect(find.byKey(ObjectKey('inv_icon_splash')), findsOneWidget);
    });

    testWidgets('should show login screen when current login is unset', (tester) async {
      when(authServiceMock.onAuthStateChanged).thenAnswer((realInvocation) => Stream.fromIterable([null]));
      when(authServiceMock.isAppleSignInAvailable()).thenAnswer((realInvocation) => Future.value(true));

      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      expect(find.byKey(ObjectKey('google_sign_in')), findsOneWidget);
      expect(find.byKey(ObjectKey('apple_sign_in')), findsOneWidget);
    });

    testWidgets('should not show apple_sign_in in Android', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      when(authServiceMock.onAuthStateChanged).thenAnswer((realInvocation) => Stream.fromIterable([null]));

      await tester.pumpWidget(MyApp());
      await tester.pump();
      expect(find.byKey(ObjectKey('google_sign_in')), findsOneWidget);
      expect(find.byKey(ObjectKey('apple_sign_in')), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('should not show apple_sign_in if IOS but older version', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(authServiceMock.onAuthStateChanged).thenAnswer((realInvocation) => Stream.fromIterable([null]));
      when(authServiceMock.isAppleSignInAvailable()).thenAnswer((realInvocation) => Future.value(false));

      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      expect(find.byKey(ObjectKey('google_sign_in')), findsOneWidget);
      expect(find.byKey(ObjectKey('apple_sign_in')), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });


  });
}
