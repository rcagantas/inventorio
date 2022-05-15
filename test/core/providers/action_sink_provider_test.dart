
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventorio/core/models/app_user.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/models/meta.dart';
import 'package:inventorio/core/models/product.dart';
import 'package:inventorio/core/providers/action_sink_provider.dart';
import 'package:inventorio/core/providers/auth_provider.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';
import 'package:inventorio/core/providers/product_provider.dart';
import 'package:inventorio/core/providers/user_provider.dart';
import 'package:mockito/mockito.dart';

import '../../mocks.dart';
import '../../mocks.mocks.dart';

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

  test('should create a new meta and user ', () async {
    final actionSink = container.read(actionSinkProvider);
    await actionSink.createNewAppUser('new_user_id');

    var userDoc = await t.store.collection('users').doc('new_user_id').get();
    AppUser user = AppUser.fromJson(userDoc.data() ?? Map());

    expect(user.userId, 'new_user_id');
    expect(user.currentInventoryId, 'uuid_123');
    expect(user.knownInventories, [user.currentInventoryId]);

    var inventoryDoc = await t.store.collection('inventory').doc(user.currentInventoryId).get();
    var meta = Meta.fromJson(inventoryDoc.data() ?? Map());
    expect(meta.uuid, user.currentInventoryId);
    expect(meta.createdBy, user.userId);
    expect(meta.name, 'Inventory');
  });

  test('should not create new user if user already exists', () async {
    await container.read(userStreamProvider.future);
    container.read(actionSinkProvider);
    verifyZeroInteractions(t.plugins.uuid);
  });

  test('should create a new inventory', () async {
    await container.read(userStreamProvider.future);
    final actionSink = container.read(actionSinkProvider);
    final meta = await actionSink.createNewMeta('userId',  'uuid_123');
    await actionSink.updateMeta(meta);

    var userDoc = await t.store.collection('users').doc('userId').get();
    AppUser actualUser = AppUser.fromJson(userDoc.data() ?? Map());
    expect(actualUser.knownInventories, ['inventory_aa', 'inventory_ab', 'uuid_123']);
    expect(actualUser.currentInventoryId, 'uuid_123');
  });

  test('should select existing inventory', () async {
    await container.read(userStreamProvider.future);
    final actionSink = container.read(actionSinkProvider);
    await actionSink.selectInventory('inventory_ab');

    var userDoc = await t.store.collection('users').doc('userId').get();
    AppUser actualUser = AppUser.fromJson(userDoc.data() ?? Map());
    expect(actualUser.knownInventories, ['inventory_aa', 'inventory_ab']);
    expect(actualUser.currentInventoryId, 'inventory_ab');
  });

  test('should not select inventory if not in current list', () async {
    await container.read(userStreamProvider.future);
    final actionSink = container.read(actionSinkProvider);
    await actionSink.selectInventory('inventory_xx');

    var userDoc = await t.store.collection('users').doc('userId').get();
    AppUser actualUser = AppUser.fromJson(userDoc.data() ?? Map());
    expect(actualUser.knownInventories, ['inventory_aa', 'inventory_ab']);
    expect(actualUser.currentInventoryId, 'inventory_aa');
  });

  test('should add new item', () async {
    await container.read(userStreamProvider.future);
    final item = new Item(uuid: 'uid', code: '123', expiry: 'expiry', dateAdded: 'dateAdded', inventoryId: 'inventory_aa');
    final actionSink = container.read(actionSinkProvider);
    await actionSink.updateItem(item);

    final actual = await t.getItem('inventory_aa', 'uid');
    expect(actual == null, false);
  });

  test('should delete item', () async {
    await container.read(userStreamProvider.future);
    final actionSink = container.read(actionSinkProvider);
    await actionSink.deleteItem(ItemBuilder('existing_item_uuid', 'existing_item_code', 'inventory_aa').build());

    final actual = await t.getItem('inventory_aa', 'existing_item_uuid');
    expect(actual, null);
  });

  test('should update product', () async {
    await container.read(userStreamProvider.future);
    final product = Product(code: '123', name: 'one two three 4', brand: 'generic', variant: null, imageUrl: 'https://via.placeholder.com/100');
    final actionSink = container.read(actionSinkProvider);
    await actionSink.updateProduct('inventory_aa', product, null);

    final item = new Item(uuid: 'x', code: '123', expiry: '', dateAdded: '', inventoryId: 'inventory_aa');
    final actual = await container.read(productStreamProvider(item).future);
    expect(actual.name, 'one two three 4');

    final productName = container.read(productProvider(item)).name;
    expect(productName, 'one two three 4');
  });

  test('should update product with image', () async {
    await container.read(userStreamProvider.future);
    final product = Product(code: '123', name: 'one two three 4', brand: 'generic', variant: null, imageUrl: 'https://via.placeholder.com/100');
    final mockFile = MockFile();

    final actionSink = container.read(actionSinkProvider);
    await actionSink.selectInventory('inventory_aa');
    try {
      await actionSink.updateProduct('inventory_aa', product, mockFile);
    } catch (e) {
      // TODO: should be mocked
      t.plugins.logger.w('catching because mocks are not complete');
    }
  });

  test('should sign out', () async {
    t = TestScaffold();
    container = ProviderContainer(overrides: [
      pluginsProvider.overrideWithValue(t.plugins),
      authStreamProvider.overrideWithValue(AsyncValue.data(t.mockUser)),
    ]);

    await container.read(actionSinkProvider).signOut();
    final auth = container.read(authProvider);
    expect(auth, null);
  });

  test('should unsubscribe from inventory', () async {
    await container.read(userStreamProvider.future);
    final actionSink = container.read(actionSinkProvider);
    await actionSink.unsubscribeFrom('inventory_aa');

    final snap = t.store.collection('users').doc('userId').get();
    final user = await snap.then((value) => AppUser.fromJson(value.data()!));

    expect(user.knownInventories!.contains('inventory_aa'), false);
    expect(user.knownInventories!.length, 1);
    expect(user.currentInventoryId, 'inventory_ab');
  });

  test('should not unsubscribe from last inventory', () async {
    t = TestScaffold();
    await t.setUpFakeStore(t.store);
    container = ProviderContainer(overrides: [
      pluginsProvider.overrideWithValue(t.plugins),
      authProvider.overrideWithValue(AuthNotifier(MockUser(
        isAnonymous: false,
        uid: 'user2',
        email: 'bob@somedomain.com',
        displayName: 'Bob',
      ), null)),
    ]);

    await container.read(userStreamProvider.future);
    final actionSink = container.read(actionSinkProvider);
    await actionSink.unsubscribeFrom('inventory_aa');

    final snap = t.store.collection('users').doc('user2').get();
    final user = await snap.then((value) => AppUser.fromJson(value.data()!));

    expect(user.knownInventories!.contains('inventory_aa'), true);
    expect(user.knownInventories!.length, 1);
    expect(user.currentInventoryId, 'inventory_aa');
  });

  test('should add inventory id if it already exists', () async {
    await container.read(userStreamProvider.future);
    final actionSink = container.read(actionSinkProvider);
    await actionSink.addInventoryId('inventory_ac');

    final snap = t.store.collection('users').doc('userId').get();
    final user = await snap.then((value) => AppUser.fromJson(value.data()!));

    expect(user.currentInventoryId, 'inventory_ac');
    expect(user.knownInventories!.contains('inventory_ac'), true);
  });

}
