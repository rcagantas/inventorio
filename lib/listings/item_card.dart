import 'package:flutter/material.dart';
import 'package:inventorio/inventory_bloc.dart';

class ItemCard extends StatelessWidget {
  final InventoryItemEx item;
  ItemCard(this.item);

  @override
  Widget build(BuildContext context) {
    return Container(
        height: 100.0,
        child: Card(
            child: Row(
                children: <Widget>[
                  Expanded(flex: 15, child: Placeholder(),),
                  Expanded(flex: 70, child: Text('${item.uuid}'),),
                  Expanded(flex: 14, child: Text('${item.expiry}'),),
                  Expanded(flex: 1, child: Placeholder(),),
                ],
            ),
        ),
    );
  }
}
