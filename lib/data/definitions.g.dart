// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'definitions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InventoryItem _$InventoryItemFromJson(Map<String, dynamic> json) {
  return InventoryItem(
      uuid: json['uuid'] as String,
      code: json['code'] as String,
      expiry: json['expiry'] as String,
      dateAdded: json['dateAdded'] as String,
      inventoryId: json['inventoryId'] as String);
}

Map<String, dynamic> _$InventoryItemToJson(InventoryItem instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'code': instance.code,
      'expiry': instance.expiry,
      'dateAdded': instance.dateAdded,
      'inventoryId': instance.inventoryId
    };

Product _$ProductFromJson(Map<String, dynamic> json) {
  return Product(
      code: json['code'] as String,
      brand: json['brand'] as String,
      name: json['name'] as String,
      variant: json['variant'] as String,
      imageUrl: json['imageUrl'] as String);
}

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'brand': instance.brand,
      'variant': instance.variant,
      'imageUrl': instance.imageUrl
    };

InventoryDetails _$InventoryDetailsFromJson(Map<String, dynamic> json) {
  return InventoryDetails(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      createdBy: json['createdBy'] as String);
}

Map<String, dynamic> _$InventoryDetailsToJson(InventoryDetails instance) =>
    <String, dynamic>{
      'uuid': instance.uuid,
      'name': instance.name,
      'createdBy': instance.createdBy
    };

UserAccount _$UserAccountFromJson(Map<String, dynamic> json) {
  return UserAccount(
      json['userId'] as String, json['currentInventoryId'] as String)
    ..knownInventories =
        (json['knownInventories'] as List)?.map((e) => e as String)?.toList();
}

Map<String, dynamic> _$UserAccountToJson(UserAccount instance) =>
    <String, dynamic>{
      'knownInventories': instance.knownInventories,
      'userId': instance.userId,
      'currentInventoryId': instance.currentInventoryId
    };
