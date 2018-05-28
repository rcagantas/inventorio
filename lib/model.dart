import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:uuid/uuid.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity/connectivity.dart';
import 'package:path/path.dart';
import 'package:quiver/core.dart';

part 'model.g.dart';

@JsonSerializable()
class InventoryItem extends Object with _$InventoryItemSerializerMixin {
  String uuid;
  String code;
  DateTime expiryDate;
  InventoryItem({this.uuid, this.code, this.expiryDate});
  String get expiryDateString => expiryDate?.toIso8601String()?.substring(0, 10) ?? 'No Expiry Date';
  factory InventoryItem.fromJson(Map<String, dynamic> json) => _$InventoryItemFromJson(json);
}

@JsonSerializable()
class Product extends Object with _$ProductSerializerMixin {
  String code;
  String name;
  String brand;
  String variant;
  Product({this.code, this.name, this.brand, this.variant});
  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);

  @override
  bool operator ==(other) {
    return other is Product &&
      code == other.code &&
      name == other.name &&
      brand == other.brand &&
      variant == other.variant;
  }

  @override
  int get hashCode => hash4(code.hashCode, name.hashCode, brand.hashCode, variant.hashCode);
}

@JsonSerializable()
class InventoryDetails extends Object with _$InventoryDetailsSerializerMixin {
  String uuid;
  String name;
  String createdBy;
  String createdOn;
  InventoryDetails({this.uuid, this.name, this.createdBy, this.createdOn});
  factory InventoryDetails.fromJson(Map<String, dynamic> json) => _$InventoryDetailsFromJson(json);
}

@JsonSerializable()
class UserAccount extends Object with _$UserAccountSerializerMixin {
  List<String> knownInventories = new List();
  String userId;
  String currentInventoryId;
  UserAccount(this.userId, this.currentInventoryId) {
    knownInventories.add(this.currentInventoryId);
  }
  factory UserAccount.fromJson(Map<String, dynamic> json) => _$UserAccountFromJson(json);
}

class AppModel extends Model {
  final Uuid uuidGenerator = new Uuid();

  UserAccount _userAccount;
  Map<String, InventoryItem> _inventoryItems = new Map();
  Map<String, Product> _products = new Map();
  Map<String, File> _productImage = new Map();

  DateTime _lastSelectedDate = new DateTime.now();

  CollectionReference _userCollection;
  CollectionReference _masterProductDictionary;
  CollectionReference _productDictionary;
  CollectionReference _inventoryItemCollection;

  List<InventoryItem> get inventoryItems {
    List<InventoryItem> toSort = _inventoryItems.values.toList();
    toSort.sort((item1, item2) => item1.expiryDate.compareTo(item2.expiryDate));
    return toSort;
  }

  AppModel() {
    _signIn();
    _reloadImages();
  }

  void _signIn() async {
    String userId;
    Directory docDir = await getApplicationDocumentsDirectory();
    File userAccountFile = new File('${docDir.path}/userAccount.json');
    if (userAccountFile.existsSync()) {
      print('Loading last known user from file.');
      UserAccount account = new UserAccount.fromJson(json.decode(userAccountFile.readAsStringSync()));
      userId = account.userId;
    }

    ConnectivityResult connectivity = await (new Connectivity().checkConnectivity());
    if (connectivity != ConnectivityResult.none) {
      GoogleSignIn googleSignIn = new GoogleSignIn();
      GoogleSignInAccount user = googleSignIn.currentUser;
      user = user == null ? await googleSignIn.signInSilently() : user;
      user = user == null ? await googleSignIn.signIn() : user;
      userId = user.id;
    }

    _loadAllCollections(userId);
  }

  void _reloadImages() async {
    Directory docDir = await getApplicationDocumentsDirectory();
    Directory imagePickerTmpDir = new Directory(docDir.parent.path + '/tmp');
    print('Reloading images from directory ${imagePickerTmpDir.path}');
    _productImage.clear();
    imagePickerTmpDir.list()
      .where((e) => e is File)
      .map((e) => e as File)
      .toList()
      .then((list) {
        list.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        list.forEach((f) {
          if (f.path.contains('image_picker')) {
            f.delete();
          } else if (f.path.contains('_')) {
            String code = basenameWithoutExtension(f.path).split('_')[0];
            if (_productImage.containsKey(code)) {
              f.delete();
            } else {
              _productImage[code] = f;
              notifyListeners();
            }
          }
        });
      });
  }

  void _loadAllCollections(String userId) async {
    _userCollection = Firestore.instance.collection('users');
    var userDoc = await _userCollection.document(userId).get();
    if (!userDoc.exists) {
      _userAccount = new UserAccount(userId, uuidGenerator.v4());
      _userCollection.document(userId).setData(_userAccount.toJson());

      Firestore.instance.collection('inventory').document(_userAccount.currentInventoryId).setData(new InventoryDetails(
        uuid: _userAccount.currentInventoryId,
        name: 'Default Inventory',
        createdBy: _userAccount.userId,
        createdOn: new DateTime.now().toIso8601String(),
      ).toJson());

    } else {
      _userAccount = new UserAccount.fromJson(userDoc.data);
    }

    Directory docDir = await getApplicationDocumentsDirectory();
    File userAccountFile = new File('${docDir.path}/userAccount.json');
    userAccountFile.writeAsString(json.encode(_userAccount));

    _masterProductDictionary = Firestore.instance.collection('productDictionary');
    _productDictionary = Firestore.instance.collection('inventory').document(_userAccount.currentInventoryId).collection('productDictionary');
    _inventoryItemCollection = Firestore.instance.collection('inventory').document(_userAccount.currentInventoryId).collection('inventoryItems');
    _inventoryItemCollection.snapshots().listen((snap) {
      print('Snapshot received');
      _inventoryItems.clear();
      snap.documents.forEach((doc) {
        InventoryItem item = new InventoryItem.fromJson(doc.data);
        _inventoryItems[doc.documentID] = item;
        notifyListeners();
        isProductIdentified(item.code);
      });
    });
  }

  Future<InventoryItem> addItemFlow(BuildContext context) async {
    print('Adding new item...');

    String code = await BarcodeScanner.scan();
    if (code == null) return null;

    DateTime expiryDate = await getExpiryDate(context);
    if (expiryDate == null) return null;

    String uuid = uuidGenerator.v4();
    InventoryItem item = new InventoryItem(uuid: uuid, code: code, expiryDate: expiryDate);
    addItem(item);
    return item;
  }

  Future<bool> isProductIdentified(String code) async {
    if (_products.containsKey(code)) return true;

    ConnectivityResult connectivity = await (new Connectivity().checkConnectivity());
    if (connectivity == ConnectivityResult.none) return false;

    print('Checking remote dictionary for $code');
    var doc = await _productDictionary.document(code).get();
    if (doc.exists) {
      _products[code] = new Product.fromJson(doc.data);
      notifyListeners();
      return true;
    }

    print('Checking remote master dictionary for $code');
    var masterDoc = await _masterProductDictionary.document(code).get();
    if (masterDoc.exists) {
      Product product = new Product.fromJson(masterDoc.data);
      _products[code] = product;
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<DateTime> getExpiryDate(BuildContext context) async {
    DateTime expiryDate = _lastSelectedDate;
    try {
      expiryDate = await showDatePicker(
          context: context,
          initialDate: _lastSelectedDate,
          firstDate: _lastSelectedDate.subtract(new Duration(days: 1)),
          lastDate: _lastSelectedDate.add(new Duration(days: 365 * 10))
      );
      print('Setting Expiry Date: [$expiryDate]');
    } catch (e) {
      print('Unknown exception $e');
    }
    return expiryDate;
  }

  void removeItem(String uuid) {
    _inventoryItems.remove(uuid);
    notifyListeners();
    _inventoryItemCollection.document(uuid).delete();
  }

  void addItem(InventoryItem item) {
    _inventoryItems[item.uuid] = item;
    print(json.encode(_inventoryItems));
    notifyListeners();
    _inventoryItemCollection.document(item.uuid).setData(item.toJson());
  }

  void addProduct(Product product) {
    _products[product.code] = product;
    _reloadImages();
    notifyListeners();

    _masterProductDictionary.document(product.code).get().then((masterDoc) {
      if (masterDoc.exists) {
        Product masterProduct = Product.fromJson(masterDoc.data);
        // don't override if only photo changed.
        if (masterProduct != product) {
          print('Overriding product dictionary for ${product.code}');
          _productDictionary.document(product.code).setData(product.toJson());
          _masterProductDictionary.document(product.code).setData(product.toJson());
        }
      } else {
        _masterProductDictionary.document(product.code).setData(product.toJson());
      }
    });
  }

  Product getAssociatedProduct(InventoryItem item) {
    return _products[item.code];
  }

  File getImage(String code) {
    return _productImage[code];
  }
}