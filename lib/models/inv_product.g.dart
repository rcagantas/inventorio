// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inv_product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvProduct _$InvProductFromJson(Map<String, dynamic> json) {
  return InvProduct(
    code: json['code'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String,
    variant: json['variant'] as String,
    imageUrl: json['imageUrl'] as String,
  );
}

Map<String, dynamic> _$InvProductToJson(InvProduct instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'brand': instance.brand,
      'variant': instance.variant,
      'imageUrl': instance.imageUrl,
    };
