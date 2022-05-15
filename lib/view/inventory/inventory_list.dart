
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/providers/auth_provider.dart';
import 'package:inventorio/core/providers/items_provider.dart';
import 'package:inventorio/core/providers/user_provider.dart';
import 'package:inventorio/view/inventory/inventory_list_tile.dart';

class InventoryList extends ConsumerWidget {
  const InventoryList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Expanded(
      child: Builder(
        builder: (context) {
          final auth = ref.watch(authProvider);
          final user = ref.watch(userProvider);

          if (auth == null || user.knownInventories == null) return Container();
          user.knownInventories!.sort((a, b) {
            final lenA = ref.watch(itemsStreamProvider(a)).value?.length ?? 0;
            final lenB = ref.watch(itemsStreamProvider(b)).value?.length ?? 0;
            return lenB - lenA;
          });
          return ListView.builder(
            itemCount: user.knownInventories?.length ?? 0,
            itemBuilder: (context, index) => InventoryListTile(
              inventoryId: user.knownInventories?[index] ?? '',
              isSelected: user.knownInventories?[index] == user.currentInventoryId,
            ),
          );
        },
      )
    );
  }
}
