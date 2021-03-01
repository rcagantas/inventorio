import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:json_annotation/json_annotation.dart';

part 'inv_product.g.dart';

@JsonSerializable()
class InvProduct implements Comparable{
  final String code;
  final String name;
  final String brand;
  final String variant;
  final String imageUrl;
  @JsonKey(ignore: true) final bool unset;

  InvProduct({
    @required this.code,
    this.name,
    this.brand,
    this.variant,
    this.imageUrl
  }) :
    this.unset = false
  ;

  InvProduct.unset({
    @required this.code,
  }) :
    this.name = null,
    this.brand = null,
    this.variant = null,
    this.imageUrl = null,
    this.unset = true
  ;

  factory InvProduct.fromJson(Map<String, dynamic> json) => _$InvProductFromJson(json);
  Map<String, dynamic> toJson() => _$InvProductToJson(this);

  @override
  bool operator ==(other) {
    return other is InvProduct
        && code == other.code
        && name == other.name
        && brand == other.brand
        && variant == other.variant
        && imageUrl == other.imageUrl
        && unset == other.unset;
  }

  int get hashCode => hashValues(code, name, brand, variant, imageUrl, unset);

  @override
  int compareTo(other) {
    if (other is InvProduct) {
      var brandComparison = '${this.brand ?? ''}'.compareTo('${other.brand ?? ''}');
      var nameComparison = '${this.name ?? ''}'.compareTo('${other.name ?? ''}');
      return brandComparison == 0 ? nameComparison : brandComparison;
    }
    return -1;
  }

  String get stringRepresentation => '${brand ?? ''} ${name ?? ''} ${variant ?? ''}';
}


class InvProductBuilder {
  String code;
  String name;
  String brand;
  String variant;
  String imageUrl;
  String heroCode;
  File imageFile;
  Future<File> resizedImageFileFuture;

  bool unset;

  InvProductBuilder({
    this.code,
    this.name,
    this.brand,
    this.variant,
    this.imageUrl,
    this.unset,
    this.heroCode
  });

  InvProductBuilder.fromProduct(InvProduct product, String heroCode) {
    this
      ..code = product.code
      ..name = product.name
      ..brand = product.brand
      ..variant = product.variant
      ..imageUrl = product.imageUrl
      ..unset = product.unset
      ..heroCode = heroCode;
  }

  InvProduct build() {
    if (this.name == null || this.name.isEmpty) {
      throw UnsupportedError(
        'InvProductBuilder cannot build with name $name'
      );
    }

    return InvProduct(
        code: this.code,
        name: this.name?.trim(),
        brand: this.brand?.trim(),
        variant: this.variant?.trim(),
        imageUrl: this.imageUrl
    );
  }

  @override
  String toString() {
    return {
      'code': this.code,
      'name': this.name,
      'brand': this.brand,
      'variant': this.variant,
      'imageUrl': this.imageUrl,
      'imageFile': this.imageFile?.path,
      'unset': this.unset,
      'heroCode': this.heroCode
    }.toString();
  }
}