
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/providers/product_provider.dart';
import 'package:inventorio/view/product/product_image_builder.dart';

class ProductImage extends ConsumerWidget {
  final Item item;
  final double imageScale;

  const ProductImage({
    Key? key,
    required this.item,
    required this.imageScale,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final dimension = 100.0 * media.textScaleFactor * imageScale;
    final productImageUrl = ref.watch(productProvider(item)).imageUrl;
    final productImageFilePath = ref.watch(productImageFilePathProvider(item.code!));
    File? imageFile = productImageFilePath != '' ? File(productImageFilePath) : null;

    return Hero(
      tag: '${item.uuid}_${item.code}',
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: SizedBox.square(
          dimension: dimension,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3.0),
            child: Stack(
              children: [
                Positioned.fill(child: ProductImageBuilder(imageUrl: productImageUrl)),
                Positioned.fill(child: imageFile == null ? Container() : Image.asset(imageFile.path, fit: BoxFit.cover)),
              ],
            )
          ),
        ),
      ),
    );
  }
}
