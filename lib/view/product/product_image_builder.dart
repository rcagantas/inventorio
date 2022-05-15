
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProductImageBuilder extends StatelessWidget {
  final String? imageUrl;
  const ProductImageBuilder({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final defaultImage = Image.asset('./resources/icons/icon_small.png');

    return Builder(
      builder: (context) => imageUrl == null || imageUrl == '' ? defaultImage : CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => defaultImage,
        errorWidget: (context, url, error) => defaultImage,
      ),
    );
  }
}
