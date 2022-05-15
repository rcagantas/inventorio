import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventorio/core/models/app_user.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:uuid/uuid.dart';

import 'mocks.mocks.dart';

@GenerateMocks([Uuid, File, FlutterLocalNotificationsPlugin])
class TestScaffold {
  late MockUser mockUser;
  late MockFirebaseAuth auth;
  late FakeFirebaseFirestore store;
  late MockFirebaseStorage storage;
  late Plugins plugins;

  TestScaffold() {
    TestWidgetsFlutterBinding.ensureInitialized();
    packageInfoMock();
    nativeTimezoneMock();
    mockUser = MockUser(
      isAnonymous: false,
      uid: 'userId',
      email: 'bob@somedomain.com',
      displayName: 'Bob',
    );
    auth = MockFirebaseAuth();
    store = FakeFirebaseFirestore();
    storage = MockFirebaseStorage();
    plugins = Plugins(
      auth: auth,
      store: store,
      storage: storage,
      uuid: MockUuid(),
      logger: Logger(printer: SimplePrinter()),
      notificationsPlugin: MockFlutterLocalNotificationsPlugin()
    );

    //when(mockUser.uid).thenReturn('userId');
    when(plugins.uuid.v1()).thenReturn('uuid_123');
  }

  Future<void> setUpFakeStore(FakeFirebaseFirestore fakeStore) async {
    await fakeStore.collection('inventory').doc('inventory_aa').set({
      'uuid': 'inventory_aa',
      'name': 'Inventory',
      'createdBy': 'userId'
    });

    await fakeStore.collection('inventory')
      .doc('inventory_aa')
      .collection('inventoryItems')
      .add(Item(uuid: 'existing_item_uuid', code: 'existing_item_code', expiry: null, dateAdded: null, inventoryId: 'inventory_aa').toJson());

    await fakeStore.collection('inventory').doc('inventory_ab').set({
      'uuid': 'inventory_ab',
      'name': 'Inventory',
      'createdBy': 'userId'
    });
    await fakeStore.collection('users').doc('userId').set({
      'knownInventories': [
        'inventory_aa',
        'inventory_ab',
      ],
      'userId': 'userId',
      'currentInventoryId': 'inventory_aa',
      'currentVersion': '3.0.0 build 88'
    });
    await fakeStore.collection('users').doc('user2').set({
      'knownInventories': [
        'inventory_aa',
      ],
      'userId': 'userId',
      'currentInventoryId': 'inventory_aa',
      'currentVersion': '3.0.0 build 88'
    });
    await fakeStore.collection('productDictionary').doc('123').set({
      'code': '123',
      'name': 'one two three',
      'brand': 'generic global',
    });
    await fakeStore.collection('productDictionary').doc('111').set({
      'code': '111',
      'name': 'one one one',
      'brand': 'generic global',
    });
    await fakeStore.collection('inventory')
      .doc('inventory_aa')
      .collection('productDictionary')
      .doc('123')
      .set({
      'code': '123',
      'name': 'one two three',
      'brand': 'generic',
      'inventoryId': 'inventory_aa',
      'imageUrl': 'https://via.placeholder.com/100',
    });
    await fakeStore.collection('inventory').doc('inventory_ac').set({
      'uuid': 'inventory_ac',
      'name': 'Inventory',
      'createdBy': 'userId'
    });
  }

  Future<Item?> getItem(String inventoryId, String uid) async {
    final snap = store.collection('inventory').doc(inventoryId).collection('inventoryItems').doc(uid).get();
    final doc = await snap.then((value) => value);
    return doc.exists ? Item.fromJson(doc.data()!) : null;
  }

  Future<AppUser> getUser(FakeFirebaseFirestore fakeStore, String userId) async {
    var userDoc = await fakeStore.collection('users').doc(userId).get();
    return AppUser.fromJson(userDoc.data() ?? Map());
  }

  MethodChannel packageInfoMock() {
    MethodChannel packageInfo = const MethodChannel('dev.fluttercommunity.plus/package_info');
    packageInfo.setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{
          'appName': 'inventorio',  // <--- set initial values here
          'packageName': 'com.rcagantas.inventorio',  // <--- set initial values here
          'version': '3.0.0',  // <--- set initial values here
          'buildNumber': '88'  // <--- set initial values here
        };
      }
      return null;
    });
    return packageInfo;
  }

  MethodChannel nativeTimezoneMock() {
    MethodChannel nativeTz = const MethodChannel('flutter_native_timezone');
    nativeTz.setMockMethodCallHandler((call) async {
      if (call.method == 'getLocalTimezone') {
        return 'Asia/Singapore';
      }
    });
    return nativeTz;
  }
}
