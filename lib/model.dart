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
  Product({this.code, this.name, this.brand});
  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
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

  DateTime _lastSelectedDate = new DateTime.now();
  String _imagePath;

  CollectionReference _userCollection;
  CollectionReference _productCollection;
  CollectionReference _inventoryItemCollection;

  List<InventoryItem> get inventoryItems {
    List<InventoryItem> toSort = _inventoryItems.values.toList();
    toSort.sort((item1, item2) => item1.expiryDate.compareTo(item2.expiryDate));
    return toSort;
  }

  AppModel() {
    _ensureSignIn();
    _initAsync();
    print('Item count: ${inventoryItems.length}');
  }

  void _ensureSignIn() async {
    GoogleSignIn googleSignIn = new GoogleSignIn();
    GoogleSignInAccount user = googleSignIn.currentUser;
    user = user == null ? await googleSignIn.signInSilently() : user;
    user = user == null ? await googleSignIn.signIn() : user;
    print('User: $user');

    _userCollection = Firestore.instance.collection('users');
    var userDoc = await _userCollection.document(user.id).get();
    if (!userDoc.exists) {
      _userAccount = new UserAccount(user.id, uuidGenerator.v4());
      _userCollection.document(user.id).setData(_userAccount.toJson());

      Firestore.instance.collection('inventory').document(_userAccount.currentInventoryId).setData(new InventoryDetails(
        uuid: _userAccount.currentInventoryId,
        name: 'Default Inventory',
        createdBy: _userAccount.userId,
        createdOn: new DateTime.now().toIso8601String(),
      ).toJson());

    } else {
      _userAccount = new UserAccount.fromJson(userDoc.data);
    }

    _productCollection = Firestore.instance.collection('productDictionary');
    _inventoryItemCollection = Firestore.instance.collection('inventory').document(_userAccount.currentInventoryId).collection('inventoryItems');

    print('Firestore: Trying to load inventory ${_userAccount.toJson()}');
    _inventoryItemCollection.getDocuments().then((snap) {
      print('Firestore: Trying to load last inventory snapshot $snap');
      snap.documents.forEach((doc) {
        InventoryItem item = new InventoryItem.fromJson(doc.data);
        print('Loaded Firestore item ${item.toJson()}');
        _inventoryItems[doc.documentID] = item;
        if (!_products.containsKey(item.code)) {
          _productCollection.document(item.code).get().then((doc) {
            Product product = new Product.fromJson(doc.data);
            _products[product.code] = product;
            notifyListeners();
          });
        }
        notifyListeners();
      });
    });
  }


  void _initAsync() async {
    Directory docDir = await getApplicationDocumentsDirectory();
    Directory imagePickerTmpDir = new Directory(docDir.parent.path + '/tmp');

    print('Image Picker temp directory ${imagePickerTmpDir.path}');
    _imagePath = imagePickerTmpDir.path;
    imagePickerTmpDir.list().forEach((f) {
      if (f.path.contains('image_picker')) {
        print('Deleting ${f.path}');
        f.delete();
      }
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
    var doc = await _productCollection.document(code).get();
    if (doc.exists) {
      _products[code] = new Product.fromJson(doc.data);
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
    notifyListeners();
    _productCollection.document(product.code).setData(product.toJson());
  }

  Product getAssociatedProduct(InventoryItem item) {
    return _products[item.code];
  }

  File getImage(String code) {
    return new File('$_imagePath/$code.jpg');
  }
}