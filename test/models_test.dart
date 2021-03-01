import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventorio/models/inv_auth.dart';
import 'package:inventorio/models/inv_expiry.dart';
import 'package:inventorio/models/inv_item.dart';
import 'package:inventorio/models/inv_meta.dart';
import 'package:inventorio/models/inv_product.dart';
import 'package:inventorio/models/inv_user.dart';
import 'package:mockito/mockito.dart';

import 'mocks.dart';

void main() {

  group('Expiry', () {

    test('inv expiry should have predictable schedule Id', () {
      var date1 = '2020-04-14T19:00:00Z';
      var date2 = '2020-04-15T19:00:00Z';

      var item1 = InvItem(uuid: 'uid', code: '01', expiry: date1, dateAdded: date1, inventoryId: 'inv id');
      var item2 = InvItem(uuid: 'uid', code: '01', expiry: date2, dateAdded: date1, inventoryId: 'inv id');

      var expiry1Red = InvExpiry(item: item1, daysOffset: item1.redOffset);
      var expiry2Red = InvExpiry(item: item2, daysOffset: item2.redOffset);

      expect(expiry1Red.scheduleId, expiry2Red.scheduleId);
    });

    test('inventoryId should be the same as item inventoryId', () {
      var date1 = '2020-04-14T19:00:00Z';
      var item1 = InvItem(uuid: 'uid', code: '01', expiry: date1, dateAdded: date1, inventoryId: 'inv id');
      var expiry1 = InvExpiry(item: item1, daysOffset : item1.redOffset);

      expect(expiry1.inventoryId, item1.inventoryId);
    });

    test('title should be the same as product brand and name', () {
      var date1 = '2020-04-14T19:00:00Z';
      var item1 = InvItem(uuid: 'uid', code: '01', expiry: date1, dateAdded: date1, inventoryId: 'inv id');
      var product1 = InvProduct(code: '01', imageUrl: 'http://x', brand: 'brand', name: 'name', variant: '1');

      var expiry1 = InvExpiry(item: item1, product: product1, daysOffset : item1.redOffset);

      expect(expiry1.title, 'brand name');
    });

    test('body should indicate days offset', () {
      var date1 = '2020-03-28T19:00:00Z';
      var item1 = InvItem(uuid: 'uid', code: '01', expiry: date1, dateAdded: date1, inventoryId: 'inv id');
      var product1 = InvProduct(code: '01', imageUrl: 'http://x', brand: 'brand', name: 'name', variant: '1');

      var expiry = InvExpiry(item: item1, product: product1, daysOffset : item1.redOffset);

      expect(expiry.body, 'is about to expire within 7 days on Mar 28');
    });

    test('alert date should be 7 and 30 days before expiry', () {
      var date1 = '2020-03-28T19:00:00Z';
      var item1 = InvItem(uuid: 'uid', code: '01', expiry: date1, dateAdded: date1, inventoryId: 'inv id');
      var product1 = InvProduct(code: '01', imageUrl: 'http://x', brand: 'brand', name: 'name', variant: '1');

      var expiry1 = InvExpiry(item: item1, product: product1, daysOffset : item1.redOffset);
      var expiry2 = InvExpiry(item: item1, product: product1, daysOffset : item1.yellowOffset);

      expect(expiry1.alertDate, DateTime.parse(date1).subtract(Duration(days: 7)));
      expect(expiry2.alertDate, DateTime.parse(date1).subtract(Duration(days: 30)));
    });

    test('to string', () {
      var date1 = '2020-03-28T19:00:00Z';
      var item1 = InvItem(uuid: 'uid', code: '01', expiry: date1, dateAdded: date1, inventoryId: 'inv id');
      var product1 = InvProduct(code: '01', imageUrl: 'http://x', brand: 'brand', name: 'name', variant: '1');

      var expiry1 = InvExpiry(item: item1, product: product1, daysOffset : item1.redOffset);
      expect(expiry1.toString(), '[2020-03-21 19:00:00.000Z][175619253] brand name is about to expire within 7 days on Mar 28');
    });

    test('should sort expiry by date', () {
      var date1 = '2020-04-14T19:00:00Z';
      var date2 = '2020-04-15T19:00:00Z';

      var item1 = InvItem(uuid: 'uid', code: '01', expiry: date1, dateAdded: date1, inventoryId: 'inv id');
      var item2 = InvItem(uuid: 'uid', code: '01', expiry: date2, dateAdded: date1, inventoryId: 'inv id');

      var expiry1Red = InvExpiry(item: item1, daysOffset: item1.redOffset);
      var expiry2Red = InvExpiry(item: item2, daysOffset: item2.redOffset);

      expect(expiry1Red.compareTo(expiry2Red), -1);
    });

    test('should elegantly fail if compared with non expiry', () {
      var date1 = '2020-04-14T19:00:00Z';

      var item1 = InvItem(uuid: 'uid', code: '01', expiry: date1, dateAdded: date1, inventoryId: 'inv id');

      var expiry1Red = InvExpiry(item: item1, daysOffset: item1.redOffset);

      expect(expiry1Red.compareTo(item1), -1);
    });
  });

  group('Item', () {

    setUp(() {
      InvItem.clock = ClockMock();
      when(InvItem.clock.now()).thenReturn(DateTime.parse('2020-03-28T15:26:00'));
    });

    tearDown(() {
      InvItem.clock = Clock();
    });

    test('should default to an expiration date if it is unset somehow', () {
      var item = InvItem(uuid: 'uid', code: '123', expiry: null);
      expect(item.expiryDate.difference(InvItem.clock.now()).inDays, 30);
    });

    test('should parse expiry date', () {
      var item = InvItem(uuid: 'uuid', code: '123', expiry: '2020-03-28T03:00:00');
      expect(item.expiryDate, DateTime.parse(item.expiry));
    });

    test('red alarm should be 7 days away', () {
      var item = InvItem(uuid: 'uuid', code: '123', expiry: '2020-03-28T03:00:00');
      expect(item.expiryDate.difference(item.redAlarm).inDays, 7);
    });

    test('yellow alarm should be 30 days away', () {
      var item = InvItem(uuid: 'uuid', code: '123', expiry: '2020-03-28T03:00:00');
      expect(item.expiryDate.difference(item.yellowAlarm).inDays, 30);
    });

    test('should be red when within 7 days', () {
      var item = InvItem(uuid: 'uuid', code: '123', expiry: '2020-03-28T03:00:00');
      expect(item.withinRed, true);
    });

    test('should be yellow when within 30 days', () {
      var item = InvItem(uuid: 'uuid', code: '123', expiry: '2020-02-28T03:00:00');
      expect(item.withinYellow, true);
    });

    test('hero code should be created for ui', () {
      var item = InvItem(uuid: 'uuid', code: '123', expiry: '2020-02-28T03:00:00');
      expect(item.heroCode, 'uuid_123');
    });

    test('should ensure valid if data from source is broken or old', () {
      var item = InvItem(uuid: 'uuid', code: '123');
      item = item.ensureValid('metaId');
      expect(item.expiry, '2020-04-27T15:26:00.000');
      expect(item.dateAdded, '2019-03-29T15:26:00.000');
      expect(item.inventoryId, 'metaId');
    });

    test('unset constructor', () {
      var unset = InvItem.unset();
      expect(unset.unset, true);
    });

    test('json conversion', () {
      var item = InvItem(uuid: 'uuid', code: '123', expiry: '2020-02-28T03:00:00');
      var json = item.toJson();
      expect(json, {
        'uuid': 'uuid',
        'code': '123',
        'expiry': '2020-02-28T03:00:00',
        'dateAdded': null,
        'inventoryId': null
      });

      var fromJson = InvItem.fromJson(json);
      expect(item, fromJson);
    });

    test('items should have predictable hash', () {
      var date = '2020-04-14T19:00:00Z';
      var item1 = InvItem(uuid: 'uid', code: '01', expiry: date, dateAdded: date, inventoryId: 'inv id');
      var item2 = InvItem(uuid: 'uid', code: '01', expiry: date, dateAdded: date, inventoryId: 'inv id');
      expect(item1.hashCode, item2.hashCode);
      expect(item1 == item2, isTrue);
    });
  });

  group('Item builder', () {

    setUp(() {
      InvItem.clock = ClockMock();
      when(InvItem.clock.now()).thenReturn(DateTime.parse('2020-03-28T15:26:00'));
    });

    tearDown(() {
      InvItem.clock = Clock();
    });

    test('should generate unique uuid', () {
      var uuid1 = InvItemBuilder.generateUuid();
      var uuid2 = InvItemBuilder.generateUuid();
      expect(uuid1 != uuid2, isTrue);
    });

    test('should default to an expiration date if it is unset somehow', () {
      var item = InvItemBuilder(expiry: null);
      expect(item.expiryDate.difference(InvItem.clock.now()).inDays, 30);
    });

    test('should parse expiry date', () {
      var item = InvItemBuilder(expiry: '2020-03-28T03:00:00');
      expect(item.expiryDate, DateTime.parse(item.expiry));
    });

    test('should add minutes and hours from \'now\' to expiry date', () {
      var item = InvItemBuilder()
        ..expiryDate = DateTime.parse('2020-02-28T00:00:00');
      expect(item.expiry, '2020-02-28T15:27:00.000');
    });

    test('build should add missing fields when it can', () {
      var builder = InvItemBuilder()
        ..code='132'
        ..inventoryId = 'metaId';

      var item = builder.build();
      expect(item.dateAdded, InvItem.clock.now().toIso8601String());
      expect(item.expiry, InvItem.clock.now().add(Duration(days: 30)).toIso8601String());
      expect(item.uuid != null, isTrue);
    });

    test('build should throw exception when missing code', () {
      var builder = InvItemBuilder()
        ..inventoryId = 'metaId';

      expect(() => builder.validate(),
          throwsA(predicate((e) => e is UnsupportedError
              && e.message == 'InvItemBuilder cannot build with code null and inventoryId metaId'))
      );
    });

    test('build from item', () {
      var date = '2020-04-14T19:00:00Z';
      var item1 = InvItem(uuid: 'uid', code: '01', expiry: date, dateAdded: date, inventoryId: 'inv id');
      var builder = InvItemBuilder.fromItem(item1);

      expect(builder.build(), item1);
      expect(builder.toJson(), item1.toJson());
      expect(builder.toString(), item1.toJson().toString());
    });
  });

  group('Meta', () {
    test('json conversion', () {
      var meta = InvMeta(uuid: 'uid', createdBy: 'enzo', name: 'inventory');
      var json = meta.toJson();

      expect(json, {
        'uuid': 'uid',
        'createdBy': 'enzo',
        'name': 'inventory'
      });

      var fromJson = InvMeta.fromJson(json);
      expect(meta.toJson(), fromJson.toJson());
    });

    test('unset', () {
      var unset = InvMeta.unset(uuid: 'uid');
      expect(unset.unset, isTrue);
    });

    test('comparison', () {
      var meta1 = InvMeta(uuid: 'uid', createdBy: 'enzo', name: 'inventory1');
      var meta2 = InvMeta(uuid: 'uid', createdBy: 'enzo', name: 'inventory2');

      expect(meta1.compareTo(meta2), -1);
    });

    test('comparison to non meta', () {
      var meta = InvMeta(uuid: 'uid', createdBy: 'enzo', name: 'inventory1');
      var item = InvItem(uuid: 'uuid', code: 'enzo', inventoryId: 'inventory1',);

      expect(meta.compareTo(item), -1);
    });
  });

  group('Meta builder', () {
    test('should build from meta', () {
      var meta = InvMeta(uuid: 'uid', createdBy: 'enzo', name: 'inventory1');
      var builder = InvMetaBuilder.fromMeta(meta);

      expect(builder.build().toJson(), meta.toJson());
    });

    test('should throw exception when building with null uuid', () {
      var builder = InvMetaBuilder();
      expect(() => builder.build(),
          throwsA(predicate((e) => e is UnsupportedError
              && e.message == 'InvMeta uuid cannot be null')));
    });
  });

  group('Product', () {

    test('unset', () {
      var unset = InvProduct.unset(code: '123');
      expect(unset.unset, isTrue);
    });

    test('json conversion', () {
      var product = InvProduct(code: '123', name: 'name', variant: 'variant', brand: 'brand', imageUrl: 'url');
      var json = product.toJson();

      expect(json, {
        'code': '123',
        'name': 'name',
        'variant': 'variant',
        'brand': 'brand',
        'imageUrl': 'url'
      });

      var fromJson = InvProduct.fromJson(json);
      expect(product, fromJson);
    });

    test('comparison', () {
      var product1 = InvProduct(code: '12311', name: 'name', variant: 'variant', brand: 'brand2', imageUrl: 'url');
      var product2 = InvProduct(code: '12312', name: 'name2', variant: 'variant', brand: 'brand', imageUrl: 'url');
      var product3 = InvProduct(code: '12313', name: 'name', variant: 'variant', brand: 'brand', imageUrl: 'url');

      var list = [product1, product2, product3];
      list.sort();

      expect(list, [product3, product2, product1]);
    });

    test('comparison to non-product', () {
      var product = InvProduct(code: '12311', name: 'name', variant: 'variant', brand: 'brand2', imageUrl: 'url');
      var item = InvItem(uuid: 'uid', code: '12311');
      expect(product.compareTo(item), -1);
    });

    test('string representation', () {
      var product = InvProduct(code: '12311', name: 'name', variant: 'variant', brand: 'brand2', imageUrl: 'url');
      expect(product.stringRepresentation, 'brand2 name variant');
    });

    test('products should have predictable hash', () {
      var product1 = InvProduct(code: '01', imageUrl: 'http://x', brand: 'brand', name: 'name', variant: '1');
      var product2 = InvProduct(code: '01', imageUrl: 'http://x', brand: 'brand', name: 'name', variant: '1');
      expect(product1.hashCode, product2.hashCode);
      expect(product1 == product2, isTrue);
    });
  });

  group('Product builder', () {

    test('build from product', () {
      var product = InvProduct(code: '01', imageUrl: 'http://x', brand: 'brand', name: 'name', variant: '1');
      var builder = InvProductBuilder.fromProduct(product, 'hero_code');
      expect(builder.build(), product);
    });

    test('throw exception when name is unset', () {
      var builder = InvProductBuilder();
      expect(() => builder.build(), throwsA(
          predicate((e) => e is UnsupportedError
              && e.message == 'InvProductBuilder cannot build with name null')));
    });

    test('to string', () {
      var product = InvProduct(code: '01', imageUrl: 'http://x', brand: 'brand', name: 'name', variant: '1');
      var builder = InvProductBuilder.fromProduct(product, 'hero_code');
      expect(builder.toString(),
          '{code: 01, name: name, brand: brand, variant: 1, imageUrl: http://x, imageFile: null, unset: false, heroCode: hero_code}');
    });
  });
  
  group('User', () {
    
    test('unset', () {
      var unset = InvUser.unset(userId: 'user');
      expect(unset.unset, isTrue);
    });

    test('json conversion', () {
      var user = InvUser(userId: 'userId', currentInventoryId: 'inventoryId', knownInventories: []);
      var json = user.toJson();
      expect(json, {
        'userId': 'userId',
        'currentInventoryId': 'inventoryId',
        'knownInventories': [],
        'currentVersion': null
      });
      
      var fromJson = InvUser.fromJson(json);
      expect(user.toJson(), fromJson.toJson());
    });
  });

  group('User builder', () {

    test('build', () {
      var builder = InvUserBuilder(userId: 'uid', knownInventories: ['id'], currentInventoryId: 'id');
      var user = builder.build();
      expect(user.userId, 'uid');
      expect(user.knownInventories, ['id']);
      expect(user.currentInventoryId, 'id');
    });

    test('build from user', () {
      var user = InvUser(userId: 'userId', currentInventoryId: 'id', knownInventories: ['id']);
      var builder = InvUserBuilder.fromUser(user);

      expect(builder.build().toJson(), user.toJson());
      expect(builder.toJson(), user.toJson());
    });

    test('should be equal', () {
      var builder1 = InvUserBuilder(userId: 'user_id', currentInventoryId: 'inv_id', knownInventories: ['inv_id']);
      var builder2 = InvUserBuilder(userId: 'user_id', currentInventoryId: 'inv_id', knownInventories: ['inv_id']);

      expect(builder1.toJson(), builder2.toJson());
    });

    test('should throw with invalid user id', () {
      var builder = InvUserBuilder(currentInventoryId: 'id', knownInventories: ['id']);
      expect(() => builder.build(), throwsA(predicate((e) => e is UnsupportedError
          && e.message == 'InvUserBuilder cannot build with userId null')));
    });

    test('should throw with invalid inventory id', () {
      var builder = InvUserBuilder(userId: 'userId', knownInventories: ['id']);
      expect(() => builder.build(), throwsA(predicate((e) => e is UnsupportedError
          && e.message == 'InvUserBuilder cannot build with currentInventoryId null')));
    });

    test('should throw with invalid inventory list', () {
      var builder = InvUserBuilder(userId: 'userId', currentInventoryId: 'id', knownInventories: []);
      expect(() => builder.build(), throwsA(predicate((e) => e is UnsupportedError
          && e.message == 'InvUserBuilder cannot build with knownInventories []')));
    });

    test('should throw with inventory not a member of list', () {
      var builder = InvUserBuilder(userId: 'userId', currentInventoryId: 'id', knownInventories: ['id2']);
      expect(() => builder.build(), throwsA(predicate((e) => e is UnsupportedError
          && e.message == 'InvUserBuilder cannot build with id not a member of [id2]')));
    });
  });

  group('Auth', () {
    test('should show email', () {
      var auth = InvAuth(email: 'a@a.a', displayName: 'a', uid: 'a1');
      expect(auth.emailDisplay, 'a@a.a');
    });
  });
}