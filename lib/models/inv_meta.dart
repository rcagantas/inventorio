import 'package:json_annotation/json_annotation.dart';

part 'inv_meta.g.dart';

@JsonSerializable()
class InvMeta implements Comparable {
  final String uuid;
  final String name;
  final String createdBy;

  @JsonKey(ignore: true) final bool unset;

  InvMeta({
    this.uuid,
    this.name,
    this.createdBy
  }) :
    unset = false;

  InvMeta.unset({
    this.uuid
  }) :
    unset = true,
    name = null,
    createdBy = null
  ;

  factory InvMeta.fromJson(Map<String, dynamic> json) => _$InvMetaFromJson(json);
  Map<String, dynamic> toJson() => _$InvMetaToJson(this);

  @override
  int compareTo(other) {
    if (other is InvMeta && other != null) {
      return this.name.compareTo(other.name);
    }
    return -1;
  }
}


class InvMetaBuilder {
  String uuid;
  String name;
  String createdBy;
  bool unset;

  InvMetaBuilder({
    this.uuid,
    this.name,
    this.createdBy,
    this.unset,
  });

  InvMetaBuilder.fromMeta(InvMeta invMeta) {
    this..uuid = invMeta.uuid
      ..name = invMeta.name
      ..createdBy = invMeta.createdBy
      ..unset = invMeta.unset;
  }

  InvMeta build() {
    if (uuid == null) {
      throw UnsupportedError('InvMeta uuid cannot be null');
    }
    return InvMeta(
      name: this.name,
      uuid: this.uuid,
      createdBy: this.createdBy
    );
  }
}