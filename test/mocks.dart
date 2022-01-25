import 'dart:core';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:inventorio/models/inv_item.dart';
import 'package:inventorio/models/inv_meta.dart';
import 'package:inventorio/models/inv_product.dart';
import 'package:inventorio/models/inv_user.dart';
import 'package:inventorio/providers/inv_state.dart';
import 'package:inventorio/providers/user_state.dart';
import 'package:inventorio/services/inv_auth_service.dart';
import 'package:inventorio/services/inv_scheduler_service.dart';
import 'package:inventorio/services/inv_store_service.dart';
import 'package:mockito/mockito.dart';

class MockCollection {
  ClockMock clockMock;
  InvAuthServiceMock authServiceMock;
  InvSchedulerServiceMock schedulerServiceMock;
  InvStoreServiceMock storeServiceMock;
  UserState userState;
  InvState invState;
  DateTime frozenDateTime = DateTime.parse('2020-03-28T15:26:00');

  Future<void> initMocks() async {

    clockMock = new ClockMock();
    when(clockMock.now()).thenReturn(frozenDateTime);

    GetIt.instance.reset();
    GetIt.instance.registerSingleton<Clock>(clockMock);
    GetIt.instance.registerSingleton<InvSchedulerService>(InvSchedulerServiceMock());
    GetIt.instance.registerLazySingleton<InvAuthService>(() => InvAuthServiceMock());
    GetIt.instance.registerLazySingleton<InvStoreService>(() => InvStoreServiceMock());
    GetIt.instance.registerLazySingleton(() => UserState());
    GetIt.instance.registerLazySingleton(() => InvState());

    authServiceMock = GetIt.instance<InvAuthService>();
    schedulerServiceMock = GetIt.instance<InvSchedulerService>();
    storeServiceMock = GetIt.instance<InvStoreService>();
    userState = GetIt.instance<UserState>();
    invState = GetIt.instance<InvState>();

    await _prepData();
  }

  Future<void> _prepData() async {
    await storeServiceMock.resetStore();
    await storeServiceMock.metaFactory(0, 3, 'inv');

    await storeServiceMock.productFactory( 0, 3, 'inv_1');
    await storeServiceMock.productFactory(10, 13, 'inv_2');
    await storeServiceMock.productFactory(20, 23, 'inv_3');

    await storeServiceMock.itemFactory( 0,  3, frozenDateTime, 'inv_1');
    await storeServiceMock.itemFactory(10, 13, frozenDateTime, 'inv_2');
    await storeServiceMock.itemFactory(20, 23, frozenDateTime, 'inv_3');

    await storeServiceMock.updateUser(InvUserBuilder(
        userId: 'user_1',
        currentInventoryId: 'inv_1',
        knownInventories: ['inv_1', 'inv_2'],
        unset: false
    ));

    await storeServiceMock.updateUser(InvUserBuilder(
        userId: 'user_2',
        currentInventoryId: 'inv_3',
        knownInventories: ['inv_3'],
        unset: false
    ));
  }
}

extension _InvocationExt on Invocation {
  List<dynamic> get pos => positionalArguments;
  Map<Symbol, dynamic> get named => namedArguments;
}

class MockPluginsManager {
  static const String CHANNEL_PACKAGE_INFO = 'plugins.flutter.io/package_info';
  static const String CHANNEL_APPLE_SIGN_IN = 'com.aboutyou.dart_packages.sign_in_with_apple';
  static const String CHANNEL_LOCAL_NOTIFICATIONS = 'dexterous.com/flutter/local_notifications';

  void setMock(String channelName, Future<dynamic> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channelName), handler);
  }

  void setupDefaultMockValues() {

    setMock(CHANNEL_PACKAGE_INFO, (call) async {
      if (call.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'inventorio',
          'packageName': 'com.rcagantas.inventorio',
          'version': '1.0.0',
          'buildNumber': '100'
        };
      }
      return null;
    });

    setMock(CHANNEL_APPLE_SIGN_IN, (call) async {
      if (call.method == 'performAuthorizationRequest') {
        return <String, dynamic>{
          'type': 'appleid',
          'identityToken': 'identityToken',
          'authorizationCode': 'authorizationCode'
        };
      } else if (call.method == 'isAvailable') {
        return Future.value(true);
      }
    });

    setMock(CHANNEL_LOCAL_NOTIFICATIONS, (call) async => <String, dynamic>{});
  }

}

ClockMock mockClock(String frozenDateTime) {
  var clockMock = ClockMock();
  DateTime date = DateTime.parse(frozenDateTime);
  when(clockMock.now()).thenReturn(date);
  return clockMock;
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class InvAuthServiceMock extends Mock implements InvAuthService {
  InvAuthService delegate;
  MockFirebaseAuth mockFirebaseAuth;

  InvAuthServiceMock() {
    delegate = InvAuthService(
        auth: MockFirebaseAuth(),
        //googleSignIn: MockGoogleSignIn(),
    );

    when(onAuthStateChanged).thenAnswer((r) => delegate.onAuthStateChanged);
    when(signInWithEmailAndPassword(email: anyNamed('email'), password: anyNamed('password')))
        .thenAnswer((r) => delegate.signInWithEmailAndPassword(email: r.named['email'], password: r.named['password']));
    when(signInWithGoogle()).thenAnswer((r) => delegate.signInWithGoogle());
    when(signInWithApple()).thenAnswer((r) => delegate.signInWithApple());
    when(signOut()).thenAnswer((r) => delegate.signOut());
    when(isAppleSignInAvailable()).thenAnswer((r) => delegate.isAppleSignInAvailable());
  }
}


class InvStoreServiceMock extends Mock implements InvStoreService {
  InvStoreService _delegate;

  InvStoreServiceMock() {
    _delegate = InvStoreService(
      //store: MockFirestoreInstance(),
      //storage: MockFirebaseStorage()
    );

    when(migrateUserFromGoogleIdIfPossible(any)).thenAnswer((r) => _delegate.migrateUserFromGoogleIdIfPossible(r.pos[0]));

    when(createNewUser(any)).thenAnswer((r) => _delegate.createNewUser(r.pos[0]));
    when(createNewMeta(any)).thenAnswer((r) => _delegate.createNewMeta(r.pos[0]));

    when(listenToUser(any)).thenAnswer((r) => _delegate.listenToUser(r.pos[0]));
    when(listenToInventoryList(any)).thenAnswer((r) => _delegate.listenToInventoryList(r.pos[0]));
    when(listenToInventoryMeta(any)).thenAnswer((r) => _delegate.listenToInventoryMeta(r.pos[0]));
    when(listenToProduct(any)).thenAnswer((r) => _delegate.listenToProduct(r.pos[0]));
    when(listenToLocalProduct(any, any)).thenAnswer((r) => _delegate.listenToLocalProduct(r.pos[0], r.pos[1]));

    when(updateUser(any)).thenAnswer((r) => _delegate.updateUser(r.pos[0]));
    when(updateMeta(any)).thenAnswer((r) => _delegate.updateMeta(r.pos[0]));
    when(updateProduct(any, any)).thenAnswer((r) => _delegate.updateProduct(r.pos[0], r.pos[1]));
    when(updateItem(any)).thenAnswer((r) => _delegate.updateItem(r.pos[0]));
    when(deleteItem(any)).thenAnswer((r) => _delegate.deleteItem(r.pos[0]));

    when(fetchProduct(any)).thenAnswer((r) => _delegate.fetchProduct(r.pos[0]));
    when(fetchLocalProduct(any, any)).thenAnswer((r) => _delegate.fetchLocalProduct(r.pos[0], r.pos[1]));
    when(fetchInvMeta(any)).thenAnswer((r) => _delegate.fetchInvMeta(r.pos[0]));

    when(uploadProductImage(any, any)).thenAnswer((r) async {
      await _delegate.uploadProductImage(r.pos[0], r.pos[1]);
      return Future.value('fake_url');
    });
  }

  Future<void> resetStore() async {
    for (var collection in ['inventory', 'products', 'users']) {
      await _delegate.store.collection(collection).get().then((snap) async {
        for (var doc in snap.docs) {
          await doc.reference.delete();
        }
      });
    }
  }

  Future<List<void>> metaFactory(int start, int end, String inventoryId) {
    var futures = List<int>.generate(end, (i) => i + 1).skip(start)
        .map((i) => updateMeta(InvMetaBuilder(uuid: '${inventoryId}_$i', name: 'Inventory')));
    return Future.wait(futures);
  }

  Future<List<void>> productFactory(int start, int end, String inventoryId) {
    var futures = List<int>.generate(end, (i) => i + 1).skip(start)
        .map((i) => updateProduct(
          InvProductBuilder(
            code: '$i',
            name: 'product_$i',
            brand: 'brand_$i',
            variant: 'variant_$i'
          ), inventoryId
        ));

    return Future.wait(futures);
  }

  Future<List<void>> itemFactory(int start, int end, DateTime date, String inventoryId) {
    var futures = List<int>.generate(end, (i) => i + 1).skip(start)
      .map((i) => updateItem(
        InvItemBuilder(
          uuid: 'item_$i', code: '$i',
          expiry: date.add(Duration(days: 5+i)).toIso8601String(),
          dateAdded: date.add(Duration(days: i)).toIso8601String(),
          inventoryId: inventoryId
        )
      ));

    return Future.wait(futures);
  }
}

class InvSchedulerServiceMock extends Mock implements InvSchedulerService {

  InvSchedulerService _delegate;
  
  InvSchedulerServiceMock() {
    _delegate = InvSchedulerService(notificationsPlugin: FlutterLocalNotificationsPlugin());

    when(this.initialize(onDidReceiveLocalNotification: anyNamed('onDidReceiveLocalNotification'), onSelectNotification: anyNamed('onSelectNotification')))
        .thenAnswer((r) => _delegate.initialize(onDidReceiveLocalNotification: r.named['onDidReceiveLocalNotification'], onSelectNotification: r.named['onSelectNotification']));
    when(this.clearScheduledTasks()).thenAnswer((r) => _delegate.clearScheduledTasks());
    when(this.delayedScheduleNotification(any, any)).thenAnswer((r) => _delegate.delayedScheduleNotification(r.pos[0], r.pos[1]));
    when(this.scheduleNotification(any)).thenAnswer((r) => _delegate.scheduleNotification(r.pos[0]));
  }
}
class FirebaseUserMock extends Mock implements User {}
class FirebaseUserInfoMock extends Mock implements UserInfo {}
class ClockMock extends Mock implements Clock {}
class FileMock extends Mock implements File {}