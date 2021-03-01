import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:inventorio/models/inv_item.dart';
import 'package:inventorio/models/inv_product.dart';
import 'package:inventorio/providers/inv_state.dart';
import 'package:inventorio/widgets/product/product_description.dart';
import 'package:inventorio/widgets/product/product_image.dart';
import 'package:provider/provider.dart';

class ProductDetail extends StatelessWidget {
  final InvItem item;

  static const int DEFAULT_MAX_LINES = 3;
  static const int DEFAULT_FLEX = 1;

  final int productMaxLines;
  final int descriptionFlex;
  final Axis axis;

  const ProductDetail({
    @required this.item,
    this.productMaxLines: DEFAULT_MAX_LINES,
    this.axis = Axis.vertical,
    this.descriptionFlex = 5
  });

  @override
  Widget build(BuildContext context) {

    return Consumer<InvState>(
      builder: (context, invState, child) {

        InvProduct product = invState.getProduct(item.code);
        var media = MediaQuery.of(context);

        return SizedBox(
          height: 80 * media.textScaleFactor,
          child: Row(
            children: <Widget>[
              Flexible(
                child: ProductImage(
                  heroCode: item.heroCode,
                  imageUrl: product.imageUrl,
                ),
              ),
              Flexible(
                flex: 4,
                child: ProductDescription(
                  product: product,
                  productMaxLines: productMaxLines,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
