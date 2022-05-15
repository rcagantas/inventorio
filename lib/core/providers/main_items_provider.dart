
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/product.dart';
import 'package:inventorio/core/providers/auth_provider.dart';
import 'package:inventorio/core/providers/items_provider.dart';
import 'package:inventorio/core/providers/product_provider.dart';
import 'package:inventorio/core/providers/sort_provider.dart';
import 'package:inventorio/core/providers/user_provider.dart';

import '../models/item.dart';

class InventoryNotifier extends StateNotifier<List<Item>> {
  final Ref ref;

  InventoryNotifier(List<Item> state, this.ref) : super(state) {
    final auth = ref.watch(authProvider);
    if (auth == null) {
      this.state = [];
    }

    final Map<Sort, int Function(Item a, Item b)> sortingFunctionMap = {
      Sort.EXPIRY: (a, b) => a.expiry!.compareTo(b.expiry ?? ''),
      Sort.DATE_ADDED: (a, b) => b.dateAdded!.compareTo(a.dateAdded ?? ''),
      Sort.PRODUCT: (a, b) {
        Product pa = ref.watch(productProvider(a));
        Product pb = ref.watch(productProvider(b));
        return pa.compareTo(pb);
      }
    };

    final user = ref.watch(userProvider);
    final inventoryId = user.currentInventoryId;
    if (inventoryId == null) {
      this.state = [];
      return;
    }

    ref.watch(itemsStreamProvider(inventoryId)).whenData((list) {
      final sorting = ref.watch(sortProvider);
      list.sort(sortingFunctionMap[sorting]);
      this.state = list;
    });
  }
}

final mainItemsProvider = StateNotifierProvider<InventoryNotifier, List<Item>>((ref) {
  return new InventoryNotifier([], ref);
});