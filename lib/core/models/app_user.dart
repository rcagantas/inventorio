
import 'package:json_annotation/json_annotation.dart';

part 'app_user.g.dart';

@JsonSerializable()
class AppUser {
  final List<String>? knownInventories;
  final String? userId;
  final String? currentInventoryId;
  final String? currentVersion;

  AppUser({
    required this.knownInventories,
    required this.userId,
    required this.currentInventoryId,
    required this.currentVersion
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);
  Map<String, dynamic> toJson() => _$AppUserToJson(this);
}

class AppUserBuilder {
  List<String>? knownInventories;
  String? userId;
  String? currentInventoryId;
  String? currentVersion;

  AppUserBuilder.fromAppUser(AppUser? user) {
    if (user != null) {
      if (user.knownInventories != null) {
        this.knownInventories = new List<String>.from(user.knownInventories!);
      }

      this..userId = user.userId
        ..currentInventoryId = user.currentInventoryId
        ..currentVersion = user.currentVersion;
    }
  }
  
  void validate() {
    if (knownInventories == null || knownInventories!.isEmpty
      || userId == null || userId == ''
      || currentInventoryId == null || currentInventoryId == ''
      || currentVersion == null || currentVersion == '' 
    ) {
      throw new Exception('Cannot build AppUser from ${_build().toJson()}');
    }
  }

  AppUser _build() {
    return AppUser(
      knownInventories: knownInventories,
      userId: userId,
      currentInventoryId: currentInventoryId,
      currentVersion: currentVersion
    );
  }
  
  AppUser build() {
    validate();
    return _build();
  }
}