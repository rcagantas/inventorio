// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUser _$AppUserFromJson(Map<String, dynamic> json) => AppUser(
      knownInventories: (json['knownInventories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      userId: json['userId'] as String?,
      currentInventoryId: json['currentInventoryId'] as String?,
      currentVersion: json['currentVersion'] as String?,
    );

Map<String, dynamic> _$AppUserToJson(AppUser instance) => <String, dynamic>{
      'knownInventories': instance.knownInventories,
      'userId': instance.userId,
      'currentInventoryId': instance.currentInventoryId,
      'currentVersion': instance.currentVersion,
    };
