// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

InventoryItem _$InventoryItemFromJson(Map<String, dynamic> json) =>
    new InventoryItem(
        uuid: json['uuid'] as String,
        code: json['code'] as String,
        expiryDate: json['expiryDate'] == null
            ? null
            : DateTime.parse(json['expiryDate'] as String));

abstract class _$InventoryItemSerializerMixin {
  String get uuid;
  String get code;
  DateTime get expiryDate;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'uuid': uuid,
        'code': code,
        'expiryDate': expiryDate?.toIso8601String()
      };
}

Product _$ProductFromJson(Map<String, dynamic> json) => new Product(
    code: json['code'] as String,
    name: json['name'] as String,
    brand: json['brand'] as String,
    variant: json['variant'] as String);

abstract class _$ProductSerializerMixin {
  String get code;
  String get name;
  String get brand;
  String get variant;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'name': name,
        'brand': brand,
        'variant': variant
      };
}

InventoryDetails _$InventoryDetailsFromJson(Map<String, dynamic> json) =>
    new InventoryDetails(
        uuid: json['uuid'] as String,
        name: json['name'] as String,
        createdBy: json['createdBy'] as String,
        createdOn: json['createdOn'] as String);

abstract class _$InventoryDetailsSerializerMixin {
  String get uuid;
  String get name;
  String get createdBy;
  String get createdOn;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'uuid': uuid,
        'name': name,
        'createdBy': createdBy,
        'createdOn': createdOn
      };
}

UserAccount _$UserAccountFromJson(Map<String, dynamic> json) => new UserAccount(
    json['userId'] as String, json['currentInventoryId'] as String)
  ..knownInventories =
      (json['knownInventories'] as List)?.map((e) => e as String)?.toList();

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
