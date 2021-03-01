import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:inventorio/models/inv_item.dart';
import 'package:inventorio/models/inv_product.dart';
import 'package:inventorio/providers/inv_state.dart';
import 'package:inventorio/widgets/product/product_description.dart';
import 'package:inventorio/widgets/product/product_image.dart';
import 'package:inventorio/widgets/product_edit/product_edit_page.dart';
import 'package:provider/provider.dart';

class ExpiryPage extends StatefulWidget {

  static const ROUTE = '/expiry';

  @override
  _ExpiryPageState createState() => _ExpiryPageState();
}

class _ExpiryPageState extends State<ExpiryPage> {

  InvItemBuilder itemBuilder;

  @override
  void initState() {
    itemBuilder = InvItemBuilder();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    itemBuilder = InvItemBuilder.fromItem(ModalRoute.of(context).settings.arguments);

    return Consumer<InvState>(
      builder: (context, invState, child) {

        var media = MediaQuery.of(context);
        var borderRadius = const BorderRadius.all(Radius.circular(10.0));
        var product = invState.getProduct(itemBuilder.code);

        return Scaffold(
          appBar: AppBar(title: Text('Set Expiry Date'),),
          floatingActionButton: FloatingActionButton(
            child: Icon(Icons.save),
            onPressed: () async {

              var product = invState.getProduct(itemBuilder.code);
              if (product.unset) {
                await Navigator.pushNamed(context, ProductEditPage.ROUTE,
                  arguments: InvProductBuilder.fromProduct(
                    InvProduct.unset(code: itemBuilder.code),
                    itemBuilder.heroCode,
                  )
                );
              }

              itemBuilder.inventoryId = invState.selectedInvMeta().uuid;
              invState.updateItem(itemBuilder);
              Navigator.pop(context);
            },
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Card(
                clipBehavior: Clip.hardEdge,
                shape: RoundedRectangleBorder(borderRadius: borderRadius,),
                child: FlatButton(
                  padding: EdgeInsets.all(0.0),
                  onPressed: () async {
                    await Navigator.pushNamed(context, ProductEditPage.ROUTE,
                      arguments: InvProductBuilder.fromProduct(
                        invState.getProduct(itemBuilder.code),
                        itemBuilder.heroCode
                      )
                    );
                  },
                  child: SizedBox(
                    height: media.size.height / 4,
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: ProductImage(
                            imageUrl: product.imageUrl,
                            heroCode: itemBuilder.heroCode,
                            borderRadius: borderRadius,
                          ),
                        ),
                        Flexible(
                          child: ProductDescription(
                            product: product,
                            productMaxLines: media.orientation == Orientation.portrait? 5 : 1,
                            addText: 'Add Product Information',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('${product.code}',
                  style: Theme.of(context).textTheme.caption
                ),
              ),
              Flexible(
                child: SizedBox(
                  height: media.size.height / 3,
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                      primaryColor: Theme.of(context).primaryColor,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: Theme.of(context).textTheme.headline6
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      onDateTimeChanged: (value) {
                        itemBuilder.expiryDate = value.add(Duration(minutes: 2));
                      },
                      initialDateTime: itemBuilder.expiryDate,
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
