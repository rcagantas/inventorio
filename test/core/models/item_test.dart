
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventorio/core/models/item.dart';

void main() {
  test('two identical items should be equals and have same hash', () async {
    DateTime now = DateTime.now();
    Item itemA = Item(code: 'code', uuid: '123', dateAdded: now.toIso8601String(), expiry: now.toIso8601String(), inventoryId: 'inventoryId');
    Item itemB = Item(code: 'code', uuid: '123', dateAdded: now.toIso8601String(), expiry: now.toIso8601String(), inventoryId: 'inventoryId');

    expect(itemA.hashCode, itemB.hashCode);
    expect(itemA, itemB);
  });

  test('should build item even if data is incorrect', () async {
    Item item = Item(uuid: 'uuid', code: 'code/something', expiry: null, dateAdded: null, inventoryId: null);
    Item actual = item.buildValid('inventoryId');
    expect(actual.code, 'code#something');
    expect(actual.expiry, isNot(null));
    expect(actual.dateAdded, isNot(null));
    expect(actual.inventoryId, 'inventoryId');
  });

  test('should return same item if constructed using valid item', () async {
    withClock(Clock.fixed(DateTime(2020, 3, 28)), () async {
      Item item = Item(uuid: 'uuid', code: '123', expiry: null, dateAdded: null, inventoryId: null)
          .buildValid('inventoryId');
      ItemBuilder builder = ItemBuilder.fromItem(item);
      expect(item, builder.build());
    });
  });

  test('should throw if item is not valid', () async {
    withClock(Clock.fixed(DateTime(2020, 3, 28)), () async {
      Item item = Item(uuid: 'uuid', code: '123', expiry: null, dateAdded: null, inventoryId: null);
      ItemBuilder builder = ItemBuilder.fromItem(item);
      expect(() => builder.build(), throwsA(isA<Exception>()));
    });
  });

  test('should create item using basic info', () async {
    withClock(Clock.fixed(DateTime(2020, 3, 28)), () async {
      ItemBuilder builder = ItemBuilder('uuid', '123', 'inventoryId');
      Item item = builder.build();
      expect(item.inventoryId, 'inventoryId');
      expect(item.expiry, isNot(null));
      expect(item.dateAdded, isNot(null));
    });
  });
}