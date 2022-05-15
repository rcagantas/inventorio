
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/providers/auth_provider.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';
import 'package:inventorio/core/providers/product_provider.dart';
import 'package:inventorio/core/providers/scheduler_provider.dart';

final itemsStreamProvider = StreamProvider.family<List<Item>, String>((ref, inventoryId) async* {
  final auth = ref.watch(authProvider);
  if (auth == null) return;

  final stream = ref.read(pluginsProvider).store
    .collection('inventory')
    .doc(inventoryId)
    .collection('inventoryItems')
    .snapshots();

  await for (final element in stream) {
    final itemList = element.docs
      .where((e) => e.exists)
      .map((e) {
        final item = Item.fromJson(e.data()).buildValid(inventoryId);
        // preload the products in memory
        ref.read(productStreamProvider(item));
        return item;
      }
    ).toList();
    ref.read(schedulerProvider).scheduleNotifications(itemList);
    yield itemList;
  }
});