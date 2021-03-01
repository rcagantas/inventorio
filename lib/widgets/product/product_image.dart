import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_extensions_methods/dart_extensions_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ProductImage extends StatelessWidget {

  final String imageUrl;
  final String heroCode;
  static final String fallbackFilePath = 'resources/icons/icon_small.png';
  final BorderRadius borderRadius;

  ProductImage({
    @required this.imageUrl,
    @required this.heroCode,
    this.borderRadius = const BorderRadius.all(Radius.circular(4.0)),
  });

  @override
  Widget build(BuildContext context) {
    var placeHolder = Image.asset(fallbackFilePath, fit: BoxFit.cover,);
    var imageOrPlaceHolder = imageUrl.isNotNullOrEmpty() ? CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => placeHolder,
      errorWidget: (context, url, error) => placeHolder,
    ) : placeHolder;

    return Hero(
      tag: heroCode,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox.expand(child: imageOrPlaceHolder)
      ),
    );
  }
}
