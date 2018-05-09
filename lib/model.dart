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
  String uuid, code;
  DateTime expiryDate;
  InventoryItem({this.uuid, this.code, this.expiryDate});
  String get expiryDateString => expiryDate?.toIso8601String()?.substring(0, 10) ?? 'No Expiry Date';

  factory InventoryItem.fromJson(Map<String, dynamic> json) => _$InventoryItemFromJson(json);
}

@JsonSerializable()
class Product extends Object with _$ProductSerializerMixin {
  String code, name, brand;
  Product({this.code, this.name, this.brand});

  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
}

@JsonSerializable()
class Meta extends Object with _$MetaSerializerMixin {
  List<String> knownInventories = new List();
  String currentInventoryMapId, currentProductMapId;
  Meta(this.currentInventoryMapId, this.currentProductMapId) {
    knownInventories.add(this.currentInventoryMapId);
  }

  factory Meta.fromJson(Map<String, dynamic> json) => _$MetaFromJson(json);
}

class AppModel extends Model {
  final Uuid uuidGenerator = new Uuid();
  final Map<String, InventoryItem> _inventoryItems = new Map();
  final Map<String, Product> _products = new Map();

  Directory _docDir;
  DateTime _lastSelectedDate = new DateTime.now();
  String _imagePath;
  Meta _meta;

  List<InventoryItem> get inventoryItems {
    List<InventoryItem> toSort = _inventoryItems.values.toList();
    toSort.sort((item1, item2) => item1.expiryDate.compareTo(item2.expiryDate));
    return toSort;
  }

  AppModel() {
    _init();
    _ensureSignIn();
    _initAsync();
    print('Item count: ${inventoryItems.length}');
  }

  void _init() async {
    _docDir = await getApplicationDocumentsDirectory();
    File metaFile = new File('${_docDir.path}/meta.json');

    if (!metaFile.existsSync()) {
      _meta = new Meta(uuidGenerator.v4(), uuidGenerator.v4());
      String metaJson = json.encode(_meta);
      metaFile.writeAsStringSync(metaJson);
      _writeInventory();
      _writeProducts();
    } else {
      print('Loading meta');
      _meta = new Meta.fromJson(json.decode(metaFile.readAsStringSync()));

      Map<String, dynamic> _inventoryJson = json.decode(new File('${_docDir.path}/${_meta.currentInventoryMapId}.json').readAsStringSync());
      _inventoryJson.forEach((key, itemJson) => _inventoryItems[key] = new InventoryItem.fromJson(itemJson));

      Map<String, dynamic> _productJson = json.decode(new File('${_docDir.path}/${_meta.currentProductMapId}.json').readAsStringSync());
      _productJson.forEach((key, productJson) => _products[key] = new Product.fromJson(productJson));
      notifyListeners();
    }
    print(_meta.toJson().toString());
  }

  void _writeInventory() {
    new File('${_docDir.path}/${_meta.currentInventoryMapId}.json').writeAsString(json.encode(_inventoryItems));
  }

  void _writeProducts() {
    new File('${_docDir.path}/${_meta.currentProductMapId}.json').writeAsString(json.encode(_products));
  }

  void _ensureSignIn() async {
    GoogleSignIn googleSignIn = new GoogleSignIn();
    GoogleSignInAccount user = googleSignIn.currentUser;
    user = user == null ? await googleSignIn.signInSilently() : user;
    user = user == null ? await googleSignIn.signIn() : user;
    print('User: $user');
  }

  void _initAsync() async {
    Directory docDir = await getApplicationDocumentsDirectory();
    Directory imagePickerTmpDir = new Directory(docDir.parent.path + '/tmp');
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

  bool isProductIdentified(String code) {
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
      print('Setting Expiry Date: [$expiryDate]');
    } catch (e) {
      print('Unknown exception $e');
    }
    return expiryDate;
  }

  void removeItem(String uuid) {
    _inventoryItems.remove(uuid);
    notifyListeners();
    _writeInventory();
  }

  void addItem(InventoryItem item) {
    _inventoryItems[item.uuid] = item;
    print(json.encode(_inventoryItems));
    notifyListeners();
    _writeInventory();
  }

  void addProduct(Product product) {
    _products[product.code] = product;
    notifyListeners();
    _writeProducts();
  }

  Product getAssociatedProduct(InventoryItem item) {
    return _products[item.code];
  }

  File getImage(String code) {
    return new File('$_imagePath/$code.jpg');
  }
}