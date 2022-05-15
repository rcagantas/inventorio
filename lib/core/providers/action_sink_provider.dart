
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/app_user.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/models/meta.dart';
import 'package:inventorio/core/models/product.dart';
import 'package:inventorio/core/providers/meta_provider.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';
import 'package:inventorio/core/providers/scheduler_provider.dart';
import 'package:inventorio/core/providers/user_provider.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

@immutable
class ActionSinkState {
  final Ref ref;

  static const String ITEMS = 'inventoryItems';
  static const String PRODUCTS = 'productDictionary';
  static const String IMAGES = 'images';

  FirebaseFirestore get store => ref.read(pluginsProvider).store;
  FirebaseStorage get storage => ref.read(pluginsProvider).storage;
  Uuid get uuid => ref.read(pluginsProvider).uuid;
  Logger get log => ref.read(pluginsProvider).logger;

  CollectionReference get _inventory => store.collection('inventory');
  CollectionReference get _users => store.collection('users');
  CollectionReference get _products => store.collection(PRODUCTS);


  ActionSinkState(this.ref);

  Future<Meta> createNewMeta(String createdBy, String newMetaId) async {
    final meta = new Meta(uuid: newMetaId, name: 'Inventory', createdBy: createdBy);
    log.i('creating new inventory ${meta.toJson()}');
    return meta;
  }

  Future<void> updateAppUser(AppUser user) async {
    log.i('updating user ${user.toJson()}');
    await _users.doc(user.userId).set(user.toJson());
  }

  Future<AppUser> createNewAppUser(String userId) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final meta = await createNewMeta(userId, uuid.v1());
    log.i('creating new inventory as part of new user');
    await _inventory.doc(meta.uuid).set(meta.toJson());
    final newUser = AppUser(
      knownInventories: [meta.uuid!],
      userId: userId,
      currentInventoryId: meta.uuid,
      currentVersion: '${packageInfo.version} build ${packageInfo.buildNumber}'
    );
    log.i('creating new user ${newUser.toJson()}');
    await updateAppUser(newUser);
    return newUser;
  }

  Future<void> selectInventory(String inventoryId) async {
    final user = ref.watch(userProvider);
    if (user.knownInventories == null || !user.knownInventories!.contains(inventoryId)) {
      return;
    }

    final userBuilder = AppUserBuilder.fromAppUser(user)
      ..currentInventoryId = inventoryId;
    log.i('selecting inventory $inventoryId');
    await updateAppUser(userBuilder.build());
  }

  Future<void> updateItem(Item item) async {
    log.i('updating item ${item.toJson()}');
    await _inventory.doc(item.inventoryId)
      .collection(ITEMS)
      .doc(item.uuid)
      .set(item.toJson());
  }

  Future<void> deleteItem(Item item) async {
    log.i('deleting item ${item.toJson()}');
    await _inventory.doc(item.inventoryId)
      .collection(ITEMS)
      .doc(item.uuid)
      .delete()
      .whenComplete(() => ref.read(schedulerProvider).cancelItem(item));
  }

  Future<String> _updateProductImage(String code, File image) async {
    final id = uuid.v1();
    final storageRef = storage.ref().child(IMAGES).child('${code}_$id.jpg');
    await storageRef.putFile(image);
    final  url = storageRef.getDownloadURL();
    log.i('Uploaded $image for $code to $url');
    return url;
  }

  Future<void> _updateProductMeta(String inventoryId, Product product) async {
    log.i('updating product ${product.toJson()}');
    _inventory.doc(inventoryId)
      .collection(PRODUCTS)
      .doc(product.code)
      .set(product.toJson());

    await _products.doc(product.code)
      .set(product.toJson());
  }

  /// update the image first then if ever, make a new product with a new image URL.
  Future<void> updateProduct(String inventoryId, Product product, File? imageFile) async {
    ProductBuilder builder = new ProductBuilder.fromProduct(product);
    if (imageFile != null) {
      final url = await _updateProductImage(product.code!, imageFile);
      builder.imageUrl = url;
    }
    await _updateProductMeta(inventoryId, builder.build());
  }

  Future<void> addMetaToUser(Meta meta) async {
    if (meta.uuid != null) {
      final user = ref.watch(userProvider);
      log.i('adding meta ${meta.uuid} to ${user.userId}');
      if (user.knownInventories != null && !user.knownInventories!.contains(meta.uuid)) {
        final userBuilder = AppUserBuilder.fromAppUser(user)
          ..knownInventories!.add(meta.uuid!)
          ..currentInventoryId = meta.uuid;

        await updateAppUser(userBuilder.build());
      }
    }
  }

  Future<void> updateMeta(Meta meta) async {
    log.i('updating meta ${meta.toJson()}');
    await _inventory.doc(meta.uuid).set(meta.toJson());
    await addMetaToUser(meta);
  }

  Future<void> signOut() async {
    ref.read(pluginsProvider).auth.signOut();
  }

  Future<void> unsubscribeFrom(String uuid) async {
    final user = ref.watch(userProvider);
    if (user.knownInventories != null &&
        user.knownInventories!.contains(uuid) &&
        user.knownInventories!.length > 1
    ) {
      log.i('removing inventory $uuid');
      AppUserBuilder userBuilder = AppUserBuilder.fromAppUser(user)
        ..knownInventories!.remove(uuid);
      if (userBuilder.currentInventoryId == uuid) {
        userBuilder.currentInventoryId = userBuilder.knownInventories![0];
      }
      updateAppUser(userBuilder.build());
    }
  }

  Future<void> addInventoryId(String inventoryId) async {
    final meta = await ref.watch(metaStreamProvider(inventoryId).future);
    await addMetaToUser(meta);
  }
}

final actionSinkProvider = StateProvider<ActionSinkState>((ref) => ActionSinkState(ref));