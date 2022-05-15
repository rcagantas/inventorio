
import 'package:json_annotation/json_annotation.dart';

part 'meta.g.dart';

@JsonSerializable()
class Meta {
  final String? uuid;
  final String? name;
  final String? createdBy;

  Meta({required this.uuid, required this.name, required this.createdBy});

  factory Meta.fromJson(Map<String, dynamic> json) => _$MetaFromJson(json);
  Map<String, dynamic> toJson() => _$MetaToJson(this);
}

class MetaBuilder {
  String? uuid;
  String? name;
  String? createdBy;

  MetaBuilder();
  MetaBuilder.fromMeta(Meta meta):
    this.uuid = meta.uuid,
    this.name = meta.name,
    this.createdBy = meta.createdBy;

  Meta build() {
    if (uuid == null) throw UnsupportedError('Meta uid cannot be null');
    return Meta(uuid: uuid?.trim(), name: name?.trim(), createdBy: createdBy?.trim());
  }
}