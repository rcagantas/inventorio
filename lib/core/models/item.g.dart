// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Item _$ItemFromJson(Map<String, dynamic> json) => Item(
      uuid: json['uuid'] as String?,
      code: json['code'] as String?,
      expiry: json['expiry'] as String?,
      dateAdded: json['dateAdded'] as String?,
      inventoryId: json['inventoryId'] as String?,
    );

Map<String, dynamic> _$ItemToJson(Item instance) => <String, dynamic>{
      'uuid': instance.uuid,
      'code': instance.code,
      'expiry': instance.expiry,
      'dateAdded': instance.dateAdded,
      'inventoryId': instance.inventoryId,
    };
