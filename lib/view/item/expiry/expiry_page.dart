
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/models/product.dart';
import 'package:inventorio/core/providers/action_sink_provider.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';
import 'package:inventorio/core/providers/product_provider.dart';
import 'package:inventorio/core/providers/sort_provider.dart';
import 'package:inventorio/core/providers/utils_provider.dart';
import 'package:inventorio/view/product/product_card.dart';


class ExpiryPage extends ConsumerWidget {
  const ExpiryPage({Key? key}) : super(key: key);
  static const double pad = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ItemBuilder itemBuilder = ItemBuilder.fromItem(ModalRoute.of(context)?.settings.arguments as Item);

    return Scaffold(
      appBar: AppBar(title: Text('Set Expiry Date'),),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.save_alt),
        onPressed: () async {
          Product product = await ref.watch(productStreamProvider(itemBuilder.build()).future);
          if (product.name == null) {
            ref.read(pluginsProvider).logger.i('pushing to edit product');
            product = await Navigator.pushNamed(context, '/edit', arguments: itemBuilder.build()) as Product;
          }

          if (product.name != null) {
            ref.read(actionSinkProvider).updateItem(itemBuilder.build());
            ref.read(sortProvider.notifier).setSort(Sort.DATE_ADDED);
          }

          Navigator.pop(context);
        },
      ),
      body: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(pad),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/edit', arguments: itemBuilder.build()),
              child: ProductCard(item: itemBuilder.build(), imageScale: 1.75,),
            ),
          ),
          Text('${itemBuilder.code}', style: Theme.of(context).primaryTextTheme.caption,),
          Padding(
            padding: const EdgeInsets.only(left: pad, right: pad),
            child: SizedBox(
              height: 250.0,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: Theme.of(context).brightness,
                  primaryColor: Theme.of(context).primaryColor,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: Theme.of(context).textTheme.headline6
                  )
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: ref.watch(utilsProvider).toDate(itemBuilder.expiry),
                  onDateTimeChanged: (DateTime value) {
                    itemBuilder.expiry = value.toIso8601String();
                  },
                ),
              ),
            ),
          )
        ]
      )
    );
  }
}
