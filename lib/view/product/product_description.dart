
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/providers/product_provider.dart';

class ProductDescription extends ConsumerWidget {
  final Item item;
  const ProductDescription({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const spacer = 5.0;
    final productRx = ref.watch(productStreamProvider(item));

    return Flexible(
      child: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: productRx.when(
          data: (product) => Builder(
            builder: (context) {
              final cachedProduct = ref.watch(productProvider(item));
              if (product.name == null && cachedProduct.name == null) {
                return Text('Edit Product Details');
              }

              final String brand = product.brand ?? cachedProduct.brand ?? '';
              final String name = product.name ?? cachedProduct.name ?? '';
              final String variant = product.variant ?? cachedProduct.variant ?? '';

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$brand',  style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.fade),
                  SizedBox(height: spacer,),
                  Text('$name', overflow: TextOverflow.fade,),
                  SizedBox(height: spacer,),
                  Text('$variant', style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.fade)
                ],
              );
            }
          ),
          error: (error, stack) => Container(),
          loading: () => CircularProgressIndicator()
        )
      ),
    );
  }
}
