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

  Map<String, InventoryItem> _inventoryItems = new Map();
  Map<String, Product> _products = new Map();
  Map<String, File> _productImage = new Map();

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
    _signIn().then((id) => _loadCollections(id));
  }

  Future<String> _signIn() async {
    String userId;

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
    } else {
      Directory appDir = await getApplicationDocumentsDirectory();
      File userAccountFile = new File('${appDir.path}/userAccount.json');
      if (userAccountFile.existsSync()) {
        print('Loading last known user from file.');
        UserAccount account = new UserAccount.fromJson(json.decode(userAccountFile.readAsStringSync()));
        userId = account.userId;
      }
    }

    return userId;
  }

  void _createNewUserAccount(String userId) {
    UserAccount userAccount = new UserAccount(userId, uuidGenerator.v4());
    _userCollection.document(userId).setData(userAccount.toJson());

    Firestore.instance.collection('inventory').document(userAccount.currentInventoryId).setData(new InventoryDetails(
      uuid: userAccount.currentInventoryId,
      name: 'Default Inventory',
      createdBy: userAccount.userId,
      createdOn: new DateTime.now().toIso8601String(),
    ).toJson());
  }

  void _loadCollections(String userId) {
    _userCollection = Firestore.instance.collection('users');
    _userCollection.document(userId).snapshots().listen((userDoc) {
      if (!userDoc.exists) _createNewUserAccount(userId);

      UserAccount userAccount = new UserAccount.fromJson(userDoc.data);
      _loadData(userAccount);

      getApplicationDocumentsDirectory().then((appDir) {
        File userAccountFile = new File('${appDir.path}/userAccount.json');
        userAccountFile.writeAsString(json.encode(userAccount));
      });
    });
  }

  void _loadData(UserAccount userAccount) async {
    _masterProductDictionary = Firestore.instance.collection('productDictionary');
    _masterProductDictionary.snapshots().listen((snap) => snap.documents.forEach((doc) => _syncProduct(doc)));
    _productDictionary = Firestore.instance.collection('inventory').document(userAccount.currentInventoryId).collection('productDictionary');
    _productDictionary.snapshots().listen((snap) => snap.documents.forEach((doc) => _syncProduct(doc, forced: true)));
    _inventoryItemCollection = Firestore.instance.collection('inventory').document(userAccount.currentInventoryId).collection('inventoryItems');
    _inventoryItemCollection.snapshots().listen((snap) {
      print('New item snapshot. Clearing inventory');
      _inventoryItems.clear();
      snap.documents.forEach((doc) {
        InventoryItem item = new InventoryItem.fromJson(doc.data);
        _inventoryItems[doc.documentID] = item;
        isProductIdentified(item.code);
        notifyListeners();
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

  void _cleanupOldImages(String fileName) async {
    Directory appDir = await getApplicationDocumentsDirectory();
    String code = fileName.split('_')[0];
    String uuid = fileName.split('_')[1];
    Directory imagePickerTmpDir = new Directory(appDir.parent.path + '/tmp');
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

  void _syncProduct(DocumentSnapshot doc, {bool forced: false}) {
    if (_products.containsKey(doc.documentID) || forced) {
      Product product = new Product.fromJson(doc.data);
      _products[product.code] = product;
      _setProductImage(product);
      notifyListeners();
    }
  }

  void _setProductImage(Product product) {
    if (product.imageFileName == null) { return; }

    if (_productImage.containsKey(product.code) &&
        _productImage[product.code].path.contains(product.imageFileName)) {
      return;
    }

    getApplicationDocumentsDirectory().then((dir) {
      File localFile = new File(dir.parent.path + '/tmp/' + product.imageFileName + '.jpg');
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
    });
  }

  Future<bool> isProductIdentified(String code) async {
    if (_products.containsKey(code)) return true;

    print('Checking remote dictionary for $code');
    var doc = await _productDictionary.document(code).get();
    if (doc.exists) _syncProduct(doc, forced: true);

    print('Checking remote master dictionary for $code');
    var masterDoc = await _masterProductDictionary.document(code).get();
    if (!doc.exists && masterDoc.exists) _syncProduct(masterDoc, forced: true);

    return _products.containsKey(code);
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
      _lastSelectedDate = expiryDate;
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
      var ref = FirebaseStorage.instance.ref().child('images').child(product.imageFileName);
      ref.putFile(_productImage[product.code]);
      _cleanupOldImages(product.imageFileName);
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