
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/providers/action_sink_provider.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';
import 'package:inventorio/core/providers/product_provider.dart';
import 'package:inventorio/view/item/expiry_label.dart';
import 'package:inventorio/view/product/product_card.dart';

class ItemCard extends ConsumerWidget {
  final Item item;
  ItemCard(this.item);

  void deleteItem(BuildContext context, WidgetRef ref) {
    ref.read(actionSinkProvider).deleteItem(item);

    String productName = ref.watch(productProvider(item)).name!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Deleted $productName'),
      action: SnackBarAction(
        label: 'UNDO',
        onPressed: () {
          ItemBuilder itemBuilder = ItemBuilder.fromItem(item);
          itemBuilder.uuid = ref.read(pluginsProvider).uuid.v1();
          ref.read(actionSinkProvider).updateItem(itemBuilder.build());
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Slidable(
      key: ObjectKey(item),
      endActionPane: ActionPane(
        dismissible: DismissiblePane(onDismissed: () { deleteItem(context, ref); }),
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            backgroundColor: Theme.of(context).backgroundColor,
            icon: Icons.delete,
            label: 'Delete',
            onPressed: (context) { deleteItem(context, ref); }
          )
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/expiry', arguments: item);
        },
        child: Stack(
          children: [
            ProductCard(item: item),
            ExpiryLabel(item: item)
          ]
        ),
      ),
    );
  }
}
