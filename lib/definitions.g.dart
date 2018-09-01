// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'definitions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InventoryItem _$InventoryItemFromJson(Map<String, dynamic> json) {
  return new InventoryItem(
      uuid: json['uuid'] as String,
      code: json['code'] as String,
      expiry: json['expiry'] as String);
}

abstract class _$InventoryItemSerializerMixin {
  String get uuid;
  String get code;
  String get expiry;
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'uuid': uuid, 'code': code, 'expiry': expiry};
}

Product _$ProductFromJson(Map<String, dynamic> json) {
  return new Product(
      code: json['code'] as String,
      brand: json['brand'] as String,
      name: json['name'] as String,
      variant: json['variant'] as String,
      imageUrl: json['imageUrl'] as String);
}

abstract class _$ProductSerializerMixin {
  String get code;
  String get name;
  String get brand;
  String get variant;
  String get imageUrl;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'name': name,
        'brand': brand,
        'variant': variant,
        'imageUrl': imageUrl
      };
}

InventoryDetails _$InventoryDetailsFromJson(Map<String, dynamic> json) {
  return new InventoryDetails(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      createdBy: json['createdBy'] as String);
}

abstract class _$InventoryDetailsSerializerMixin {
  String get uuid;
  String get name;
  String get createdBy;
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'uuid': uuid, 'name': name, 'createdBy': createdBy};
}

UserAccount _$UserAccountFromJson(Map<String, dynamic> json) {
  return new UserAccount(
      json['userId'] as String, json['currentInventoryId'] as String)
    ..knownInventories =
        (json['knownInventories'] as List)?.map((e) => e as String)?.toList();
}

abstract class _$UserAccountSerializerMixin {
  List<String> get knownInventories;
  String get userId;
  String get currentInventoryId;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'knownInventories': knownInventories,
        'userId': userId,
        'currentInventoryId': currentInventoryId
      };
}
