import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:uuid/uuid.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity/connectivity.dart';
import 'package:quiver/core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

part 'model.g.dart';

@JsonSerializable()
class InventoryItem extends Object with _$InventoryItemSerializerMixin {
  String uuid;
  String code;
  int expiryMs;

  InventoryItem({this.uuid, this.code, this.expiryMs});
  factory InventoryItem.fromJson(Map<String, dynamic> json) => _$InventoryItemFromJson(json);

  DateTime get expiryDate => DateTime.fromMillisecondsSinceEpoch(expiryMs);
  String get year => DateFormat.y().format(expiryDate);
  String get month => DateFormat.MMM().format(expiryDate);
  String get day => DateFormat.d().format(expiryDate);
}

@JsonSerializable()
class Product extends Object with _$ProductSerializerMixin {
  String code;
  String name;
  String brand;
  String variant;
  String imageUrl;

  Product({this.code, this.name, this.brand, this.variant, this.imageUrl});
  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);

  @override
  int get hashCode => hashObjects(toJson().values);

  @override
  bool operator ==(other) {
    return other is Product &&
      code == other.code &&
      name == other.name &&
      brand == other.brand &&
      variant == other.variant &&
      imageUrl == other.imageUrl;
  }
}

@JsonSerializable()
class InventoryDetails extends Object with _$InventoryDetailsSerializerMixin {
  String uuid;
  String name;
  String createdBy;
  InventoryDetails({this.uuid, this.name, this.createdBy});
  factory InventoryDetails.fromJson(Map<String, dynamic> json) => _$InventoryDetailsFromJson(json);
}

@JsonSerializable()
class UserAccount extends Object with _$UserAccountSerializerMixin {
  List<String> knownInventories = List();
  String userId;
  String currentInventoryId;
  UserAccount(this.userId, this.currentInventoryId) {
    knownInventories.add(this.currentInventoryId);
  }
  factory UserAccount.fromJson(Map<String, dynamic> json) => _$UserAccountFromJson(json);
}

class AppModel extends Model {
  final Uuid uuidGenerator = Uuid();

  Map<String, InventoryItem> _inventoryItems = Map();
  Map<String, Product> _products = Map();
  Map<String, Product> _productsMaster = Map();
  Uint8List imageData;
  InventoryDetails info;

  CollectionReference _userCollection;
  CollectionReference _masterProductDictionary;
  CollectionReference _productDictionary;
  CollectionReference _inventoryItemCollection;
  GoogleSignInAccount _gUser;

  List<InventoryItem> get inventoryItems {
    List<InventoryItem> toSort = _inventoryItems.values.toList();
    toSort.sort((item1, item2) => item1.expiryDate.compareTo(item2.expiryDate));
    return toSort;
  }

  AppModel() {
    _cleanupOldImages();
    _signIn().then((id) => _loadCollections(id));
  }

  Future<String> _signIn() async {
    String userId;

    ConnectivityResult connectivity = await (Connectivity().checkConnectivity());
    if (connectivity != ConnectivityResult.none) {
      GoogleSignIn googleSignIn = GoogleSignIn();
      _gUser = googleSignIn.currentUser;
      _gUser = _gUser == null ? await googleSignIn.signInSilently() : _gUser;
      _gUser = _gUser == null ? await googleSignIn.signIn() : _gUser;
      userId = _gUser.id;
      notifyListeners();
      _gUser.authentication.then((auth) {
        print('Firebase sign-in with Google: $userId');
        FirebaseAuth.instance.signInWithGoogle(
          idToken: auth.idToken,
          accessToken: auth.accessToken
        );
      });
    } else {
      Directory appDir = await getApplicationDocumentsDirectory();
      File userAccountFile = File('${appDir.path}/userAccount.json');
      if (userAccountFile.existsSync()) {
        print('Loading last known user from file.');
        UserAccount account = UserAccount.fromJson(json.decode(userAccountFile.readAsStringSync()));
        userId = account.userId;
      }
    }

    return userId;
  }

  void _createNewUserAccount(String userId) {
    UserAccount userAccount = UserAccount(userId, uuidGenerator.v4());
    _userCollection.document(userId).setData(userAccount.toJson());

    Firestore.instance.collection('inventory').document(userAccount.currentInventoryId).setData(InventoryDetails(
      uuid: userAccount.currentInventoryId,
      name: 'Inventory',
      createdBy: userAccount.userId,
    ).toJson());
  }

  void _loadCollections(String userId) {
    _userCollection = Firestore.instance.collection('users');
    _userCollection.document(userId).snapshots().listen((userDoc) {
      if (!userDoc.exists) _createNewUserAccount(userId);

      UserAccount userAccount = UserAccount.fromJson(userDoc.data);
      _loadData(userAccount);

      getApplicationDocumentsDirectory().then((appDir) {
        File userAccountFile = File('${appDir.path}/userAccount.json');
        userAccountFile.writeAsString(json.encode(userAccount));
      });
    });
  }

  void _loadData(UserAccount userAccount) {
    Firestore.instance.collection('inventory').document(userAccount.currentInventoryId).snapshots().listen((doc) {
      info = InventoryDetails.fromJson(doc.data);
      notifyListeners();
    });

    _masterProductDictionary = Firestore.instance.collection('productDictionary');
    _productDictionary = Firestore.instance.collection('inventory').document(userAccount.currentInventoryId).collection('productDictionary');
    _inventoryItemCollection = Firestore.instance.collection('inventory').document(userAccount.currentInventoryId).collection('inventoryItems');
    _inventoryItemCollection.snapshots().listen((snap) {
      print('New inventory snapshot. Clearing.');
      _inventoryItems.clear();
      snap.documents.forEach((doc) {
        InventoryItem item = InventoryItem.fromJson(doc.data);
        _inventoryItems[doc.documentID] = item;
        print('Loaded ${item.uuid}');
        notifyListeners();
        _syncProductCode(item.code);
      });
    });
  }

  void _cleanupOldImages() {
    getApplicationDocumentsDirectory().then((appDir) {
      Directory imagePickerTmpDir = Directory(appDir.parent.path + '/tmp');
      imagePickerTmpDir.list()
        .where((e) => e is File && e.path.endsWith('jpg'))
        .map((e) => e as File)
        .forEach((f) {
          print('Deleting ${f.path}');
          f.delete();
        });
    });
  }

  void _syncProduct(DocumentSnapshot doc, Map productMap) {
    if (doc.exists) {
      Product product = Product.fromJson(doc.data);
      productMap[product.code] = product;
      notifyListeners();
    }
  }

  void _syncProductCode(String code) {
    if (getAssociatedProduct(code) != null) return; // avoid multiple sync
    _productDictionary.document(code).snapshots().listen((doc) => _syncProduct(doc, _products));
    _masterProductDictionary.document(code).snapshots().listen((doc) => _syncProduct(doc, _productsMaster));
  }

  Future<bool> isProductIdentified(String code) async {
    print('Checking remote dictionary for $code');
    var doc = await _productDictionary.document(code).get();
    if (doc.exists) return true;

    print('Checking remote master dictionary for $code');
    var masterDoc = await _masterProductDictionary.document(code).get();
    if (masterDoc.exists) return true;

    return false;
  }

  void removeItem(String uuid) {
    print('Trying to delete item $uuid');
    _inventoryItemCollection.document(uuid).delete();
  }

  void addItem(InventoryItem item) {
    print('Trying to add item ${item.toJson()}');
    _inventoryItemCollection.document(item.uuid).setData(item.toJson());
  }

  Future<Product> _uploadProductImage(Product product) async {
    if (imageData == null || imageData.isEmpty) return product;
    String uuid = uuidGenerator.v4();
    String fileName = '${product.code}_$uuid.jpg';
    StorageReference storage = FirebaseStorage.instance.ref().child('images').child(fileName);
    StorageUploadTask uploadTask = storage.putData(imageData);
    UploadTaskSnapshot uploadSnap = await uploadTask.future;
    product.imageUrl = uploadSnap.downloadUrl.toString();
    print('Uploaded $fileName to ${product.imageUrl}');
    return product;
  }

  void addProduct(Product product) {
    _syncProductCode(product.code);
    _productsMaster[product.code] = product;
    notifyListeners(); // temporarily set to trigger updates on UI while we wait for server.

    _uploadProductImage(product).then((product) {

      print('Trying to add product ${product.code}');
      _masterProductDictionary.document(product.code).get().then((masterDoc) {
        if (masterDoc.exists) {
          Product masterProduct = Product.fromJson(masterDoc.data);
          if (masterProduct != product) {
            print('Overriding product dictionary: ${product.code}');
            _productDictionary.document(product.code).setData(product.toJson());
            _masterProductDictionary.document(product.code).setData(product.toJson());
          }
        } else {
          print('Adding to master dictionary: ${product.code}');
          _masterProductDictionary.document(product.code).setData(product.toJson());
        }
      });

    });
  }

  Product getAssociatedProduct(String code) {
    return _products.containsKey(code)? _products[code] : _productsMaster[code];
  }

  String get userDisplayName => _gUser?.displayName ?? '';
  String get userImageUrl => _gUser?.photoUrl ?? '';

  Future<InventoryItem> buildInventoryItem(BuildContext context) async {
    print('Scanning new item...');
    String code = await BarcodeScanner.scan();
    print('Code: $code');
    if (code == null) return null;

    DateTime expiryDate = await getExpiryDate(context);
    if (expiryDate == null) return null;

    String uuid = uuidGenerator.v4();
    InventoryItem item = InventoryItem(uuid: uuid, code: code, expiryMs: expiryDate.millisecondsSinceEpoch);
    return item;
  }

  DateTime _lastSelectedDate = DateTime.now();
  Future<DateTime> getExpiryDate(BuildContext context) async {
    print('Getting expiry date');
    DateTime expiryDate = _lastSelectedDate;
    try {
      expiryDate = await showDatePicker(
        context: context,
        initialDate: _lastSelectedDate,
        firstDate:  DateTime.now().subtract(Duration(days: 1)),
        lastDate: _lastSelectedDate.add(Duration(days: 365 * 10))
      );
      _lastSelectedDate = expiryDate;
      print('Setting Expiry Date: [$expiryDate]');
    } catch (e) {
      print('Unknown exception $e');
    }
    return expiryDate;
  }
}