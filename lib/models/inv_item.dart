import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'inv_item.g.dart';

@JsonSerializable()
class InvItem {
  final String uuid;
  final String code;
  final String expiry;
  final String dateAdded;
  final String inventoryId;

  @JsonKey(ignore: true) final bool unset;
  @JsonKey(ignore: true) final int redOffset = 7;
  @JsonKey(ignore: true) final int yellowOffset = 30;
  @JsonKey(ignore: true) static Clock clock = GetIt.instance<Clock>();

  DateTime get expiryDate => expiry == null
      ? clock.now().add(Duration(days: 30))
      : DateTime.parse(expiry);

  DateTime get redAlarm => expiryDate.subtract(Duration(days: redOffset));
  DateTime get yellowAlarm => expiryDate.subtract(Duration(days: yellowOffset));

  bool get withinRed => redAlarm.difference(clock.now()).inDays <= 0;
  bool get withinYellow => yellowAlarm.difference(clock.now()).inDays <= 0;

  String get heroCode => uuid + '_' + code;

  InvItem ensureValid(String invMetaId) {
    String expiry = this.expiry;
    String dateAdded = this.dateAdded;
    String inventoryId = this.inventoryId;

    if (this.expiry == null) { expiry = expiryDate.toIso8601String(); }
    if (this.dateAdded == null) {
      dateAdded = clock.now()
          .subtract(Duration(days: 365))
          .toIso8601String();
    }
    if (this.inventoryId == null) { inventoryId = invMetaId; }

    return InvItem(
      uuid: this.uuid,
      code: this.code,
      expiry: expiry,
      dateAdded: dateAdded,
      inventoryId: inventoryId
    );
  }

  InvItem({
    @required this.uuid,
    @required this.code,
    this.expiry,
    this.dateAdded,
    this.inventoryId
  }) :
    this.unset = false
  ;

  InvItem.unset() :
    this.uuid = null,
    this.code = null,
    this.expiry = null,
    this.dateAdded = null,
    this.inventoryId = null,
    this.unset = true
  ;

  factory InvItem.fromJson(Map<String, dynamic> json) => _$InvItemFromJson(json);
  Map<String, dynamic> toJson() => _$InvItemToJson(this);

  @override
  bool operator ==(other) {
    return other is InvItem
        && uuid == other.uuid
        && code == other.code
        && expiry == other.expiry
        && dateAdded == other.dateAdded
        && inventoryId == other.inventoryId;
  }
  
  @override
  int get hashCode => hashValues(uuid, code, expiry, dateAdded, inventoryId);
}

class InvItemBuilder {

  static final Uuid _uuid = Uuid();

  static String generateUuid() => _uuid.v4();

  String uuid;
  String code;
  String expiry;
  String dateAdded;
  String inventoryId;
  String heroCode;

  DateTime get expiryDate {
    return expiry == null
        ? InvItem.clock.now().add(Duration(days: 30))
        : DateTime.tryParse(expiry);
  }

  set expiryDate(DateTime expiryDateTime) {
    DateTime now = InvItem.clock.now();
    expiryDateTime = expiryDateTime.add(
        Duration(hours: now.hour, minutes: now.minute + 1, seconds: now.second)
    );
    expiry = expiryDateTime.toIso8601String();
  }

  InvItem build() {
    validate();

    return InvItem(
        uuid: uuid,
        code: code,
        expiry: expiry,
        dateAdded: dateAdded,
        inventoryId: inventoryId
    );
  }

  InvItemBuilder({
    this.uuid,
    this.code,
    this.expiry,
    this.dateAdded,
    this.inventoryId,
  });

  InvItemBuilder.fromItem(InvItem item) {
    this..uuid = item.uuid
      ..code = item.code
      ..expiry = item.expiry
      ..dateAdded = item.dateAdded
      ..inventoryId = item.inventoryId
      ..heroCode = item.heroCode;
  }

  @override
  String toString() {
    return build().toJson().toString();
  }

  void validate() {
    if (code == null || inventoryId == null) {
      throw UnsupportedError(
        'InvItemBuilder cannot build with code $code and inventoryId $inventoryId'
      );
    }

    DateTime now = InvItem.clock.now();
    dateAdded = dateAdded == null
        ? now.toIso8601String()
        : dateAdded;

    expiry = expiry == null
        ? now.add(Duration(days: 30)).toIso8601String()
        : expiry;

    uuid = uuid == null
        ? generateUuid()
        : uuid;
  }

  Map<String, dynamic> toJson() {
    return build().toJson();
  }
}