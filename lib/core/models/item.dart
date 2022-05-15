
import 'package:clock/clock.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:quiver/core.dart';

part 'item.g.dart';

@JsonSerializable()
class Item {
  final String? uuid;
  final String? code;
  final String? expiry;
  final String? dateAdded;
  final String? inventoryId;

  Item({
    required this.uuid,
    required this.code,
    required this.expiry,
    required this.dateAdded,
    required this.inventoryId
  });

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
  Map<String, dynamic> toJson() => _$ItemToJson(this);

  Item buildValid(String inventoryId) {
    return Item(
      uuid: this.uuid,
      code: this.code?.replaceAll('/', '#'),
      expiry: this.expiry ?? Clock().daysFromNow(30).toIso8601String(),
      dateAdded: this.dateAdded ?? Clock().now().toIso8601String(),
      inventoryId: this.inventoryId ?? inventoryId
    );
  }

  @override
  bool operator ==(other) {
    return other is Item
      && uuid == other.uuid
      && code == other.code
      && expiry == other.expiry
      && inventoryId == other.inventoryId;
  }

  @override
  int get hashCode => hashObjects([uuid, code, expiry, inventoryId]);

  @override
  String toString() => this.toJson().toString();
}

class ItemBuilder {
  String? uuid;
  String? code;
  String? expiry;
  String? dateAdded;
  String? inventoryId;

  ItemBuilder(this.uuid, this.code, this.inventoryId);

  ItemBuilder.fromItem(Item item) {
    this..uuid = item.uuid
      ..code = item.code
      ..expiry = item.expiry
      ..dateAdded = item.dateAdded
      ..inventoryId = item.inventoryId
    ;
  }

  Item _build() {
    return Item(uuid: uuid, code: code, expiry: expiry, dateAdded: dateAdded, inventoryId: inventoryId);
  }

  Item build() {
    final item = _build();
    if (this.inventoryId == null || this.inventoryId == '') throw Exception('Cannot build item $item');
    return item.buildValid(this.inventoryId!);
  }
}
