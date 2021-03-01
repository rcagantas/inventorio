import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventorio/models/inv_auth.dart';
import 'package:inventorio/models/inv_item.dart';
import 'package:inventorio/models/inv_meta.dart';
import 'package:inventorio/models/inv_product.dart';
import 'package:inventorio/models/inv_status.dart';
import 'package:inventorio/models/inv_user.dart';
import 'package:inventorio/providers/inv_state.dart';

import 'package:logger/logger.dart';
import 'package:mockito/mockito.dart';

import '../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  InvState invState;
  InvStoreServiceMock storeServiceMock;
  InvSchedulerServiceMock schedulerServiceMock;
  ClockMock clockMock;
  MockCollection mocks = MockCollection();
  MockPluginsManager mockPluginsManager = MockPluginsManager();

  group('Inv State Provider', () {

    setUp(() async {
      Logger.level = Level.debug;

      mockPluginsManager.setupDefaultMockValues();
      await mocks.initMocks();

      storeServiceMock = mocks.storeServiceMock;
      schedulerServiceMock = mocks.schedulerServiceMock;
      clockMock = mocks.clockMock;

      invState = new InvState();
    });

    test('should load user on state change', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      verify(storeServiceMock.listenToUser('user_1')).called(1);
      verify(storeServiceMock.listenToInventoryList('inv_1')).called(1);
      verify(storeServiceMock.listenToInventoryMeta('inv_1')).called(1);
      verify(storeServiceMock.listenToLocalProduct('inv_1', any)).called(3);
      verify(storeServiceMock.listenToProduct(any)).called(6);
      expect(invState.isLoading(), isFalse);
      expect(invState.selectedInvMeta().uuid, 'inv_1');
      expect(invState.invMetas.map((e) => e.uuid), ['inv_1', 'inv_2']);
      Set<String> expected = new Set()..addAll(['item_1', 'item_2', 'item_3']);
      expect(invState.selectedInvList().map((e) => e.uuid).toSet(), expected);
      expect(invState.inventoryItemCount('inv_1'), 3);
      verify(schedulerServiceMock.delayedScheduleNotification(any, any)).called(greaterThan(0));
    });

    test('should return default meta if user not fully loaded', () async {
      var meta = invState.selectedInvMeta();
      expect(meta.name, 'Inventory');
    });

    test('should persist new user', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_3'));

      verify(storeServiceMock.migrateUserFromGoogleIdIfPossible(any)).called(1);
      verify(storeServiceMock.createNewUser('user_3')).called(1);
    });

    test('should migrate existing user from gId', () async {

      storeServiceMock.updateUser(InvUserBuilder(
          userId: 'google_sign_in_id',
          currentInventoryId: 'inv_3',
          knownInventories: ['inv_3'],
          unset: false
      ));

      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_4', googleSignInId: 'google_sign_in_id'));

      expect(invState.invUser.currentInventoryId, 'inv_3');
    });

    test('should cancel subscriptions on logout', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      await invState.clear();
      expect(invState.invUser.unset, isTrue);
    });

    test('should listen to user changes', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      expect(invState.selectedInvMeta().name, 'Inventory');

      storeServiceMock.updateUser(InvUserBuilder(
          userId: 'user_1',
          currentInventoryId: 'inv_2',
          knownInventories: ['inv_1', 'inv_2']
      ));

      await invState.isReady();
      expect(invState.selectedInvMeta().uuid, 'inv_2');
      expect(invState.invMetas.map((e) => e.uuid), ['inv_1', 'inv_2']);
      verify(schedulerServiceMock.delayedScheduleNotification(any, any)).called(greaterThan(0));
    });

    test('should toggle sorting by cycling modes', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      expect(invState.sortingKey, InvSort.EXPIRY);
      expect(invState.selectedInvList().map((e) => e.uuid).toList(), ['item_1', 'item_2', 'item_3']);

      invState.toggleSort();
      expect(invState.sortingKey, InvSort.DATE_ADDED);
      expect(invState.selectedInvList().map((e) => e.uuid).toList(), ['item_3', 'item_2', 'item_1']);

      invState.toggleSort();
      expect(invState.sortingKey, InvSort.PRODUCT);
      expect(invState.selectedInvList().map((e) => e.uuid).toList(), ['item_1', 'item_2', 'item_3']);
    });

    test('select inventory should update user', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      await invState.selectInventory('inv_2');

      var expected = InvUserBuilder.fromUser(invState.invUser)..currentInventoryId = 'inv_2';
      var verification = verify(storeServiceMock.updateUser(captureAny));
      expect(verification.captured.last.currentInventoryId, expected.currentInventoryId);
      verify(schedulerServiceMock.delayedScheduleNotification(any, any)).called(greaterThan(0));
    });

    test('should trigger load on selection of notification', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      invState.onSelectNotification('inv_2');

      var expected = InvUserBuilder.fromUser(invState.invUser)..currentInventoryId = 'inv_2';
      var verification = verify(storeServiceMock.updateUser(captureAny));
      expect(verification.captured.last.currentInventoryId, expected.currentInventoryId);
    });

    test('selecting inv meta should select inventory', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      await invState.selectInvMeta(InvMeta(uuid: 'inv_2'));

      var expected = InvUserBuilder.fromUser(invState.invUser)..currentInventoryId = 'inv_2';
      var verification = verify(storeServiceMock.updateUser(captureAny));
      expect(verification.captured.last.currentInventoryId, expected.currentInventoryId);
      verify(schedulerServiceMock.delayedScheduleNotification(any, any)).called(greaterThan(0));
    });

    test('should remove item', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      var item = InvItem(uuid: 'inv_1', code: '1');

      await invState.removeItem(item);
      verify(storeServiceMock.deleteItem(item)).called(1);
      verify(schedulerServiceMock.delayedScheduleNotification(any, any)).called(greaterThan(0));
    });

    test('should update item', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      var item = InvItem(uuid: 'inv_1', code: '1', inventoryId: 'inv_id1');
      var itemBuilder = InvItemBuilder.fromItem(item);
      itemBuilder.expiryDate = DateTime.now();

      await invState.updateItem(itemBuilder);
      verify(storeServiceMock.updateItem(itemBuilder)).called(1);
      verify(schedulerServiceMock.delayedScheduleNotification(any, any)).called(greaterThan(0));
    });

    test('should not update item if the product is unset', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      var item = InvItem(uuid: 'inv_1', code: '99', inventoryId: 'inv_id1');
      var itemBuilder = InvItemBuilder.fromItem(item);

      await invState.updateItem(itemBuilder);
      verifyNever(storeServiceMock.updateItem(itemBuilder));
    });

    test('should not update product when user is unset', () async {
      var builder = InvProductBuilder.fromProduct(invState.getProduct('1'), '')
        ..brand = 'brand_1x';
      await invState.updateProduct(builder);
      verifyNever(storeServiceMock.updateProduct(builder, 'inv_1'));
    });

    test('should not update product if product never changed', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      var builder = InvProductBuilder.fromProduct(invState.getProduct('1'), '');
      await invState.updateProduct(builder);
      verifyNever(storeServiceMock.updateProduct(builder, 'inv_1'));
    });

    test('should update product', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      var builder = InvProductBuilder.fromProduct(invState.getProduct('1'), '')
        ..brand = 'brand_1x';
      await invState.updateProduct(builder);
      verify(storeServiceMock.updateProduct(builder, 'inv_1')).called(1);
      expect(builder.build(), invState.getProduct('1'));
      verify(schedulerServiceMock.delayedScheduleNotification(any, any)).called(greaterThan(0));
    });

    test('should update product with image', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      var imageFileMock = new FileMock();
      var resizedFileMock = new FileMock();

      var builder = InvProductBuilder.fromProduct(invState.getProduct('1'), '')
        ..brand = 'brand_1x'
        ..imageFile = imageFileMock
        ..resizedImageFileFuture = Future<File>.value(resizedFileMock);

      await invState.updateProduct(builder);
      verify(storeServiceMock.updateProduct(builder, 'inv_1')).called(2);
      expect(builder.build(), invState.getProduct('1'));
      verify(imageFileMock.delete()).called(1);
      verify(resizedFileMock.delete()).called(1);
      expect(invState.getProduct('1').imageUrl, isNotNull);
    });

    test('should edit inventory name', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      var builder = InvMetaBuilder.fromMeta(invState.selectedInvMeta())
        ..name = 'new_inventory_name';
      await invState.updateInvMeta(builder);
      verify(storeServiceMock.updateMeta(builder)).called(1);

      await Future.delayed(Duration(milliseconds: 10));
      expect(invState.selectedInvMeta().name, 'new_inventory_name');
    });

    test('should unsubscribe from inventory', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      var uuid = 'inv_2';
      await invState.unsubscribeFromInventory(uuid);

      var builder = InvUserBuilder.fromUser(invState.invUser)
        ..currentVersion = '1.0.0 build 100'
        ..knownInventories.remove(uuid);

      verify(storeServiceMock.updateUser(builder)).called(1);
      verify(schedulerServiceMock.delayedScheduleNotification(any, any)).called(greaterThan(0));
    });


    test('should select first inventory if unsubscribing from currently selected inventory', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      var uuid = 'inv_1';
      await invState.unsubscribeFromInventory(uuid);

      var builder = InvUserBuilder.fromUser(invState.invUser)
        ..currentVersion = '1.0.0 build 100'
        ..currentInventoryId = 'inv_2'
        ..knownInventories.remove(uuid);

      verify(storeServiceMock.updateUser(builder)).called(1);
      verify(schedulerServiceMock.delayedScheduleNotification(any, any)).called(greaterThan(0));
    });

    test('should add inventory', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      var uuid = 'inv_3';
      await invState.addInventory(uuid);

      var builder = InvUserBuilder.fromUser(invState.invUser)
        ..currentVersion = '1.0.0 build 100'
        ..currentInventoryId = uuid
        ..knownInventories.add(uuid);

      verify(storeServiceMock.fetchInvMeta(uuid)).called(1);
      verify(storeServiceMock.updateUser(builder)).called(1);
      verify(schedulerServiceMock.delayedScheduleNotification(any, any)).called(greaterThan(0));
    });

    test('should select inventory if trying to add existing uuid', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      var uuid = 'inv_2';
      await invState.addInventory(uuid);

      var builder = InvUserBuilder.fromUser(invState.invUser)
        ..currentVersion = '1.0.0 build 100'
        ..currentInventoryId = uuid
        ..knownInventories.add(uuid);

      verify(storeServiceMock.fetchInvMeta(uuid)).called(1);
      verifyNever(storeServiceMock.updateUser(builder));

      var expected = InvUserBuilder.fromUser(invState.invUser)..currentInventoryId = 'inv_2';
      var verification = verify(storeServiceMock.updateUser(captureAny));
      expect(verification.captured.last.currentInventoryId, expected.currentInventoryId);
      verify(schedulerServiceMock.delayedScheduleNotification(any, any)).called(greaterThan(0));
    });

    test('should behave if trying to add inventory that does not exist', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      var uuid = 'inv_bogus';
      await invState.addInventory(uuid);

      var builder = InvUserBuilder.fromUser(invState.invUser)
        ..currentVersion = '1.0.0 build 100'
        ..currentInventoryId = uuid
        ..knownInventories.add(uuid);

      verify(storeServiceMock.fetchInvMeta(uuid)).called(1);
      verifyNever(storeServiceMock.updateUser(builder));
    });

    test('should create new inventory', () async {
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      invState.createNewInventory();
      verify(storeServiceMock.createNewMeta(invState.invUser.userId)).called(1);
    });

    test('should run scheduler even if all the items have not fully loaded their products', () async {

      storeServiceMock.itemFactory(3,  4, clockMock.now(), 'inv_1');
      await invState.userStateChange(status: InvStatus.Authenticated, auth: InvAuth(uid: 'user_1'));

      verify(schedulerServiceMock.clearScheduledTasks()).called(1);
      verify(schedulerServiceMock.delayedScheduleNotification(any, any)).called(greaterThan(0));
    });
  });
}