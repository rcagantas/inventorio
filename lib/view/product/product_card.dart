
import 'package:flutter/material.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/view/product/product_image.dart';
import 'package:inventorio/view/product/product_description.dart';

class ProductCard extends StatelessWidget {
  final Item item;
  final double imageScale;
  const ProductCard({Key? key, required this.item, this.imageScale = 0.80}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Row(
        children: [
          ProductImage(item: item, imageScale: imageScale,),
          ProductDescription(item: item),
        ],
      ),
    );
  }
}
