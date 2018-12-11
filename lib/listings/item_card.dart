import 'package:flutter/material.dart';
import 'package:inventorio/inventory_bloc.dart';

class ItemCard extends StatelessWidget {
  final InventoryItemEx item;
  ItemCard(this.item);

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Row(
            children: <Widget>[
              Expanded(flex: 3, child: Placeholder(),),
              Expanded(flex: 10, child: Text('${item.inventoryId}')),
              Expanded(flex: 1, child: Placeholder())
            ],
        )
    );
  }
}
