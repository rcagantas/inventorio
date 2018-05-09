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
    brand: json['brand'] as String);

abstract class _$ProductSerializerMixin {
  String get code;
  String get name;
  String get brand;
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'code': code, 'name': name, 'brand': brand};
}

Meta _$MetaFromJson(Map<String, dynamic> json) => new Meta(
    json['currentInventoryMapId'] as String,
    json['currentProductMapId'] as String)
  ..knownInventories =
      (json['knownInventories'] as List)?.map((e) => e as String)?.toList();

abstract class _$MetaSerializerMixin {
  List<String> get knownInventories;
  String get currentInventoryMapId;
  String get currentProductMapId;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'knownInventories': knownInventories,
        'currentInventoryMapId': currentInventoryMapId,
        'currentProductMapId': currentProductMapId
      };
}
