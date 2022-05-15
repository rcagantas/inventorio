
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/providers/action_sink_provider.dart';
import 'package:inventorio/core/providers/items_provider.dart';
import 'package:inventorio/core/providers/meta_provider.dart';
import 'package:inventorio/view/inventory/inventory_name.dart';

class InventoryListTile extends ConsumerWidget {
  final String inventoryId;
  final bool isSelected;
  const InventoryListTile({Key? key, required this.inventoryId, required this.isSelected}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      selected: this.isSelected,
      title: InventoryName(inventoryId: this.inventoryId),
      subtitle: Text('Items: ${ref.watch(itemsStreamProvider(inventoryId)).value?.length ?? 0}'),
      onTap: () {
        ref.read(actionSinkProvider).selectInventory(inventoryId);
        Navigator.pop(context);
      },
      trailing: IconButton(
        icon: Icon(Icons.qr_code),
        onPressed: () async {
          final meta = await ref.watch(metaStreamProvider(this.inventoryId).future);
          await Navigator.pushNamed(context, '/inventory', arguments: meta);
        },
      ),
    );
  }
}
