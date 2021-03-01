import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:inventorio/models/inv_auth.dart';
import 'package:inventorio/models/inv_item.dart';
import 'package:inventorio/models/inv_meta.dart';
import 'package:inventorio/models/inv_product.dart';
import 'package:inventorio/models/inv_user.dart';
import 'package:inventorio/utils/log/log_printer.dart';
import 'package:logger/logger.dart';
import 'package:package_info/package_info.dart';
import 'package:uuid/uuid.dart';

class InvContainer {
  final InvMeta invMeta;
  final List<InvItem> invList;

  InvContainer({this.invMeta, this.invList});
}

class InvStoreService {
  final logger = Logger(printer: SimpleLogPrinter('InvStoreService'));
  static final Uuid _uuid = Uuid();

  static const String ITEMS = 'inventoryItems';
  static const String PRODUCTS = 'productDictionary';
  static const String IMAGES = 'images';

  FirebaseFirestore store;
  FirebaseStorage storage;
  String _currentVersion;

  CollectionReference get _users => store.collection('users');
  CollectionReference get _inventory => store.collection('inventory');
  CollectionReference get _products => store.collection(PRODUCTS);

  static String generateUuid() => _uuid.v4();

  InvStoreService({
    this.store,
    this.storage
  }) {
    PackageInfo.fromPlatform().then((value) => _currentVersion = '${value.version} build ${value.buildNumber}');
  }

  Stream<InvUser> listenToUser(String uid) {
    return _users.doc(uid).snapshots()
        .map((event) {
          return event.exists
              ? InvUser.fromJson(event.data())
              : InvUser.unset(userId: uid);
        });
  }

  Stream<InvMeta> listenToInventoryMeta(String invMetaId) {
    return _inventory.doc(invMetaId).snapshots()
        .map((event) {
          return event.exists
              ? InvMeta.fromJson(event.data())
              : InvMeta(uuid: invMetaId);
        });
  }

  Future<InvMeta> fetchInvMeta(String uuid) async {
    if (uuid == null || uuid.isEmpty) {
      return InvMeta.unset(uuid: uuid);
    }
    
    return _inventory.doc(uuid).get()
        .then((value) {
          return value.exists
            ? InvMeta.fromJson(value.data())
            : InvMeta.unset(uuid: uuid);
        });
  }

  Stream<List<InvItem>> listenToInventoryList(String invMetaId) {
    return _inventory.doc(invMetaId).collection(ITEMS).snapshots()
        .map((event) => event.docs
          .map((e) => InvItem.fromJson(e.data()))
          .map((e) => e.ensureValid(invMetaId))
          .toList());
  }

  Stream<InvProduct> listenToProduct(String code) {
    return _products.doc(code).snapshots()
        .map((event) {
          return event.exists
              ? InvProduct.fromJson(event.data())
              : InvProduct.unset(code: code);
        });
  }

  Future<InvProduct> fetchProduct(String code) async {
    return await _products.doc(code).get().then((value) {
      return value.exists
          ? InvProduct.fromJson(value.data())
          : InvProduct.unset(code: code);
    });
  }

  Stream<InvProduct> listenToLocalProduct(String invMetaId, String code) {
    return _inventory.doc(invMetaId).collection(PRODUCTS)
        .doc(code)
        .snapshots()
        .map((event) {
          return event.exists
              ? InvProduct.fromJson(event.data())
              : InvProduct.unset(code: code);
        });
  }

  Future<InvProduct> fetchLocalProduct(String invMetaId, String code) async {
    return _inventory.doc(invMetaId).collection(PRODUCTS)
        .doc(code)
        .get()
        .then((value) {
          return value.exists
              ? InvProduct.fromJson(value.data())
              : InvProduct.unset(code: code);
        });
  }

  InvMetaBuilder createNewMeta(String createdByUid) {
    logger.i('Creating new meta for $createdByUid');
    return InvMetaBuilder(
      createdBy: createdByUid,
      name: 'Inventory',
      uuid: generateUuid()
    );
  }

  InvUser createNewUser(String uid) {
    InvMetaBuilder metaBuilder = createNewMeta(uid);
    updateMeta(metaBuilder);

    var userBuilder = InvUserBuilder(
        currentInventoryId: metaBuilder.uuid,
        knownInventories: [metaBuilder.uuid],
        userId: uid,
        currentVersion: _currentVersion
    );

    logger.i('Creating new user ${userBuilder.toJson()}');
    updateUser(userBuilder);
    return userBuilder.build();
  }

  Future<InvUser> updateUser(InvUserBuilder userBuilder) async {
    userBuilder.currentVersion = _currentVersion;
    InvUser user = userBuilder.build();
    logger.d('Updating user ${user.toJson()}');
    await _users.doc(user.userId).set(user.toJson());
    return user;
  }

  Future<InvMeta> updateMeta(InvMetaBuilder metaBuilder) async {
    var meta = metaBuilder.build();
    logger.d('Updating meta ${meta.toJson()}');
    await _inventory.doc(meta.uuid).set(meta.toJson());
    return meta;
  }

  Future<void> migrateUserFromGoogleIdIfPossible(InvAuth invAuth) async {
    var firebaseUid = invAuth.uid;
    var googleSignInId = invAuth.googleSignInId;

    if (googleSignInId == null || googleSignInId == '') {
      return;
    }

    DocumentSnapshot googleSnapshot = await _users.doc(googleSignInId).get();
    DocumentSnapshot firebaseSnapshot = await _users.doc(firebaseUid).get();

    if (googleSnapshot.exists && !firebaseSnapshot.exists) {
      logger.i('Migrating gId $googleSignInId to $firebaseUid');

      InvUser googleInvUser = InvUser.fromJson(googleSnapshot.data());
      await _users.doc(firebaseUid).set(InvUser(
        userId: firebaseUid,
        currentInventoryId: googleInvUser.currentInventoryId,
        knownInventories: googleInvUser.knownInventories
      ).toJson());
    }
  }

  Future<void> deleteItem(InvItem item) async {
    logger.d('Deleting item ${item.toJson()}');
    await _inventory.doc(item.inventoryId)
        .collection(ITEMS)
        .doc(item.uuid)
        .delete();
  }

  Future<void> updateItem(InvItemBuilder itemBuilder) async {
    var item = itemBuilder.build();
    logger.d('Updating item ${item.toJson()}');
    await _inventory.doc(item.inventoryId)
        .collection(ITEMS)
        .doc(item.uuid)
        .set(item.toJson());
  }

  Future<void> updateProduct(InvProductBuilder productBuilder, String inventoryId) async {
    var product = productBuilder.build();
    await _inventory.doc(inventoryId)
        .collection(PRODUCTS)
        .doc(product.code)
        .set(product.toJson());

    await _products.doc(product.code)
        .set(product.toJson());
  }

  Future<String> uploadProductImage(String code, File image) async {
    var uuid = generateUuid();
    var fileName = '${code}_$uuid.jpg';
    var storageReference = storage.ref().child(IMAGES).child(fileName);
    var uploadTask = storageReference.putData(image.readAsBytesSync());

    await uploadTask.onComplete;
    String url = await storageReference.getDownloadURL();

    logger.i('Uploaded ${image.path} to $url with $uploadTask');
    return url;
  }
}