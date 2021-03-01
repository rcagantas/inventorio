// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inv_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvItem _$InvItemFromJson(Map<String, dynamic> json) {
  return InvItem(
    uuid: json['uuid'] as String,
    code: json['code'] as String,
    expiry: json['expiry'] as String,
    dateAdded: json['dateAdded'] as String,
    inventoryId: json['inventoryId'] as String,
  );
}

Map<String, dynamic> _$InvItemToJson(InvItem instance) => <String, dynamic>{
      'uuid': instance.uuid,
      'code': instance.code,
      'expiry': instance.expiry,
      'dateAdded': instance.dateAdded,
      'inventoryId': instance.inventoryId,
    };
