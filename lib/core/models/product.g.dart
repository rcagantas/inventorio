// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
      code: json['code'] as String?,
      name: json['name'] as String?,
      brand: json['brand'] as String?,
      variant: json['variant'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'brand': instance.brand,
      'variant': instance.variant,
      'imageUrl': instance.imageUrl,
    };
