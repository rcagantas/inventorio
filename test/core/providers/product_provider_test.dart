
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/providers/auth_provider.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';
import 'package:inventorio/core/providers/product_provider.dart';
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

  test('should return same product for same item', () async {
    await container.read(userStreamProvider.future);
    Item itemA = Item(code: '123', uuid: 'item_1', dateAdded: '', expiry: '', inventoryId: 'inventory_aa');
    Item itemB = Item(code: '123', uuid: 'item_1', dateAdded: '', expiry: '', inventoryId: 'inventory_aa');

    final productA = await container.read(productStreamProvider(itemA).future);
    final productB = await container.read(productStreamProvider(itemB).future);
    expect(productA,  productB);
  });

  test('should return global product if local product is not available', () async {
    await container.read(userStreamProvider.future);
    Item item = Item(code: '111', uuid: 'item_1', dateAdded: '', expiry: '', inventoryId: 'inventory_aa');
    final product = await container.read(productStreamProvider(item).future);
    expect(product.name, 'one one one');
  });
}