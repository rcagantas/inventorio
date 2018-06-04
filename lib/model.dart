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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity/connectivity.dart';
import 'package:quiver/core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

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
  String imageFileName;
  Product({this.code, this.name, this.brand, this.variant, this.imageFileName});
  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);

  @override
  bool operator ==(other) {
    return other is Product &&
      code == other.code &&
      name == other.name &&
      brand == other.brand &&
      variant == other.variant &&
      imageFileName == other.imageFileName;
  }

  @override
  int get hashCode => hashObjects(toJson().values);
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

  Directory _appDir;
  DateTime _lastSelectedDate = new DateTime.now();

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
    getApplicationDocumentsDirectory().then((dir) {
      _appDir = dir;
      _signIn();
    });
  }

  void _signIn() async {
    String userId;
    File userAccountFile = new File('${_appDir.path}/userAccount.json');
    if (userAccountFile.existsSync()) {
      print('Loading last known user from file.');
      UserAccount account = new UserAccount.fromJson(json.decode(userAccountFile.readAsStringSync()));
      userId = account.userId;
    }

    ConnectivityResult connectivity = await (new Connectivity().checkConnectivity());
    if (connectivity != ConnectivityResult.none) {
      GoogleSignIn googleSignIn = new GoogleSignIn();
      _gUser = googleSignIn.currentUser;
      _gUser = _gUser == null ? await googleSignIn.signInSilently() : _gUser;
      _gUser = _gUser == null ? await googleSignIn.signIn() : _gUser;
      userId = _gUser.id;
      notifyListeners();
      _gUser.authentication.then((auth) =>
        FirebaseAuth.instance.signInWithGoogle(
          idToken: auth.idToken,
          accessToken: auth.accessToken
        )
      );
    }

    _loadAllCollections(userId);
  }

  void _cleanupOldImages(String fileName) async {
    String code = fileName.split('_')[0];
    String uuid = fileName.split('_')[1];
    Directory imagePickerTmpDir = new Directory(_appDir.parent.path + '/tmp');
    imagePickerTmpDir.list()
      .where((e) => e is File &&
        e.path.endsWith('jpg') &&
        e.path.contains(code) &&
        !e.path.contains(uuid))
      .map((e) => e as File)
      .forEach((f) {
        print('Deleting ${f.path}');
        f.delete();
      });
  }

  void _syncProduct(DocumentSnapshot doc) {
    if (_products.containsKey(doc.documentID)) {
      Product product = new Product.fromJson(doc.data);
      _products[product.code] = product;
      _setProductImage(product);
      notifyListeners();
    }
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
    _masterProductDictionary.snapshots().listen((snap) => snap.documents.forEach((doc) => _syncProduct(doc)));
    _productDictionary = Firestore.instance.collection('inventory').document(_userAccount.currentInventoryId).collection('productDictionary');
    _productDictionary.snapshots().listen((snap) => snap.documents.forEach((doc) => _syncProduct(doc)));
    _inventoryItemCollection = Firestore.instance.collection('inventory').document(_userAccount.currentInventoryId).collection('inventoryItems');
    _inventoryItemCollection.snapshots().listen((snap) {
      print('New item snapshot. Clearing inventory');
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

  void _setProductImage(Product product) {
    if (product.imageFileName == null) { return; }

    if (_productImage.containsKey(product.code) &&
        _productImage[product.code].path.contains(product.imageFileName)) {
      return;
    }

    File localFile = new File(_appDir.parent.path + '/tmp/' + product.imageFileName + '.jpg');
    if (!localFile.existsSync()) {
      print('Checking image ${product.code} from remote file');
      FirebaseStorage.instance.ref().child('images').child(product.imageFileName)
        .getDownloadURL().then((url) {
          print('Downloaded image ${product.code} from $url');
          http.get(url).then((response) {
            localFile.writeAsBytes(response.bodyBytes).then((f) {
              _productImage[product.code] = f;
              notifyListeners();
            });
          });
        });
    } else {
      print('Checking image ${product.code} from local file ${localFile.path}');
      _productImage[product.code] = localFile;
      notifyListeners();
    }
  }

  Future<bool> isProductIdentified(String code) async {
    if (_products.containsKey(code)) return true;

    ConnectivityResult connectivity = await (new Connectivity().checkConnectivity());
    if (connectivity == ConnectivityResult.none) return false;

    Product product;
    print('Checking remote dictionary for $code');
    var doc = await _productDictionary.document(code).get();
    if (doc.exists) product = new Product.fromJson(doc.data);

    print('Checking remote master dictionary for $code');
    var masterDoc = await _masterProductDictionary.document(code).get();
    if (!doc.exists && masterDoc.exists) product = new Product.fromJson(masterDoc.data);

    if (product != null) {
      _products[code] = product;
      _setProductImage(product);
      notifyListeners();
    }

    return product != null;
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

  String _capitalizeWord(String sentence) {
    return sentence.split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ').trim();
  }

  Product _capitalize(Product product) {
    product.brand = _capitalizeWord(product.brand);
    product.name = _capitalizeWord(product.name);
    product.variant = _capitalizeWord(product.variant);
    return product;
  }

  void addProduct(Product product) {
    _products[product.code] = _capitalize(product);
    _setProductImage(product);
    notifyListeners();

    _masterProductDictionary.document(product.code).get().then((masterDoc) {
      if (masterDoc.exists) {
        Product masterProduct = Product.fromJson(masterDoc.data);
        if (masterProduct != product) {
          print('Overriding product dictionary for ${product.code}');
          _productDictionary.document(product.code).setData(product.toJson());
          _masterProductDictionary.document(product.code).setData(product.toJson());
        }
      } else {
        _masterProductDictionary.document(product.code).setData(product.toJson());
      }
    });

    if (_productImage[product.code] != null) {
      print('Uploading ${product.imageFileName}...');
      _cleanupOldImages(product.imageFileName);
      var ref = FirebaseStorage.instance.ref().child('images').child(product.imageFileName);
      ref.putFile(_productImage[product.code]);
    }
  }

  Product getAssociatedProduct(InventoryItem item) {
    return _products[item.code];
  }

  File getImage(String code) {
    return _productImage[code];
  }

  String get userDisplayName => _gUser?.displayName ?? '';
  String get userImageUrl => _gUser?.photoUrl ?? '';
}