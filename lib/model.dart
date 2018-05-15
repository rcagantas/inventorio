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
class InventoryContainer extends Object with _$InventoryContainerSerializerMixin {
  Map<String, InventoryItem> inventoryItems = new Map();
  Map<String, Product> products = new Map();
  String uuid;
  String name;
  String createdBy;
  String createdOn;
  InventoryContainer({this.uuid, this.name, this.createdBy, this.createdOn});
  factory InventoryContainer.fromJson(Map<String, dynamic> json) => _$InventoryContainerFromJson(json);
}

@JsonSerializable()
class UserAccount extends Object with _$UserAccountSerializerMixin {
  List<String> knownInventories = new List();
  String userId;
  String currentInventoryId;
  String currentProductId;
  UserAccount(this.userId, this.currentInventoryId, this.currentProductId) {
    knownInventories.add(this.currentInventoryId);
  }
  factory UserAccount.fromJson(Map<String, dynamic> json) => _$UserAccountFromJson(json);
}

class AppModel extends Model {
  final Uuid uuidGenerator = new Uuid();

  InventoryContainer _container = new InventoryContainer();
  UserAccount _userAccount;
  DateTime _lastSelectedDate = new DateTime.now();
  String _imagePath;
  Directory _appDir;

  List<InventoryItem> get inventoryItems {
    List<InventoryItem> toSort = _container.inventoryItems.values.toList();
    toSort.sort((item1, item2) => item1.expiryDate.compareTo(item2.expiryDate));
    return toSort;
  }

  AppModel() {
    _initAsync();
    _ensureSignIn();
    print('Item count: ${inventoryItems.length}');
  }

  void _writeInventory() {
    //new File('${_docDir.path}/${_meta.currentInventoryMapId}.json').writeAsString(json.encode(_inventoryItems));
  }

  void _writeProducts() {
    //new File('${_docDir.path}/${_meta.currentProductMapId}.json').writeAsString(json.encode(_products));
  }

  void _initAsync() async {
    _appDir = await getApplicationDocumentsDirectory();
    Directory imagePickerTmpDir = new Directory(_appDir.parent.path + '/tmp');
    print('App directory ${_appDir.path}');

    File userAccountFile = new File('${_appDir.path}/userAccount.json');
    if (userAccountFile.existsSync()) {
      _userAccount = new UserAccount.fromJson(json.decode(userAccountFile.readAsStringSync()));
      print('Decoded user account: ${_userAccount.toJson()}');
    }

    print('Image Picker temp directory ${imagePickerTmpDir.path}');
    _imagePath = imagePickerTmpDir.path;
    imagePickerTmpDir.list().forEach((f) {
      if (f.path.contains('image_picker')) {
        print('Deleting ${f.path}');
        f.delete();
      }
    });
  }

  void _ensureSignIn() async {
    GoogleSignIn googleSignIn = new GoogleSignIn();
    GoogleSignInAccount user = googleSignIn.currentUser;
    user = user == null ? await googleSignIn.signInSilently() : user;
    user = user == null ? await googleSignIn.signIn() : user;
    print('User: $user');
    File userAccountFile = new File('${_appDir.path}/userAccount.json');
    if (!userAccountFile.existsSync()) {
      userAccountFile.writeAsString(json.encode(new UserAccount(user.id, uuidGenerator.v4(), uuidGenerator.v4())));
    }
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

  bool isProductIdentified(String code) {
    return _container.products.containsKey(code);
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
    _container.inventoryItems.remove(uuid);
    notifyListeners();
    _writeInventory();
  }

  void addItem(InventoryItem item) {
    _container.inventoryItems[item.uuid] = item;
    print(json.encode(_container.inventoryItems));
    notifyListeners();
    _writeInventory();
  }

  void addProduct(Product product) {
    _container.products[product.code] = product;
    notifyListeners();
    _writeProducts();
  }

  Product getAssociatedProduct(InventoryItem item) {
    return _container.products[item.code];
  }

  File getImage(String code) {
    return new File('$_imagePath/$code.jpg');
  }
}