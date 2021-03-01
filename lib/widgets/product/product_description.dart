import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:inventorio/models/inv_product.dart';

class ProductDescription extends StatelessWidget {

  final InvProduct product;
  final int productMaxLines;
  final String addText;

  ProductDescription({
    this.product,
    this.productMaxLines = 1,
    this.addText
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Visibility(
        visible: !product.unset,
        replacement: Text('${addText ?? ''}',
          style: Theme.of(context).textTheme.headline6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Flexible(
              child: Text('${product.brand ?? ''}',
                style: Theme.of(context).textTheme.subtitle2,
                overflow: TextOverflow.ellipsis
              ),
            ),
            Flexible(
              child: Text('${product.name ?? ''}',
                style: Theme.of(context).textTheme.subtitle1,
                softWrap: true,
                maxLines: productMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text('${product.variant ?? ''}',
                overflow: TextOverflow.ellipsis
              ),
            ),
          ],
        ),
      ),
    );
  }
}
