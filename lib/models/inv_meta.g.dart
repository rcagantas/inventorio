// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inv_meta.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InvMeta _$InvMetaFromJson(Map<String, dynamic> json) {
  return InvMeta(
    uuid: json['uuid'] as String,
    name: json['name'] as String,
    createdBy: json['createdBy'] as String,
  );
}

Map<String, dynamic> _$InvMetaToJson(InvMeta instance) => <String, dynamic>{
      'uuid': instance.uuid,
      'name': instance.name,
      'createdBy': instance.createdBy,
    };
