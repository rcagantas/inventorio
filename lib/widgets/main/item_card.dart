import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:inventorio/models/inv_item.dart';
import 'package:inventorio/models/inv_product.dart';
import 'package:inventorio/providers/inv_state.dart';
import 'package:inventorio/widgets/expiry/expiry_page.dart';
import 'package:provider/provider.dart';

import 'product_detail.dart';

class ItemCard extends StatelessWidget {
  static const double DOT_WIDTH = 10.0;

  final InvItem item;
  const ItemCard(this.item);

  Color getExpiryColor() {
    Color expiryColor = Colors.green;
    expiryColor = item.withinYellow ? Colors.orange : expiryColor;
    expiryColor = item.withinRed ? Colors.red: expiryColor;
    return expiryColor;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InvState>(
      builder: (context, invState, child) {
        Color expiryColor = getExpiryColor();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
          child: Card(
            clipBehavior: Clip.hardEdge,
            child: Slidable(
              actionPane: SlidableDrawerActionPane(),
              secondaryActions: <Widget>[
                IconSlideAction(
                  color: Theme.of(context).backgroundColor,
                  caption: 'Delete',
                  icon: Icons.delete,
                  onTap: () async {
                    InvProduct product = invState.getProduct(item.code);
                    invState.removeItem(item);

                    Scaffold.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Removed ${product.name}'),
                        action: SnackBarAction(
                          label: 'UNDO',
                          onPressed: () {
                            invState.updateItem(InvItemBuilder.fromItem(item));
                          }
                        ),
                      )
                    );

                  },
                ),
              ],
              child: Stack(
                children: <Widget>[
                  FlatButton(
                    padding: EdgeInsets.all(0.0),
                    onPressed: () {
                      Navigator.pushNamed(context, ExpiryPage.ROUTE, arguments: item);
                    },
                    child: ProductDetail(item: item, productMaxLines: 1,)
                  ),
                  Positioned(
                    right: 0.0,
                    bottom: 0.0,
                    child: Row(
                      children: <Widget>[
                        Text('${DateFormat('d MMM y').format(item.expiryDate)}',),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            width: DOT_WIDTH,
                            height: DOT_WIDTH,
                            decoration: new BoxDecoration(
                              color: expiryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );  
      },
    );
  }
}
