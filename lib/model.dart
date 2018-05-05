import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:uuid/uuid.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:path_provider/path_provider.dart';

class InventoryItem {
  String uuid, code;
  DateTime expiryDate;
  InventoryItem({this.uuid, this.code, this.expiryDate});
  String get expiryDateString => expiryDate?.toIso8601String()?.substring(0, 10) ?? 'No Expiry Date';
  Map<String, String> toMap() => { "uuid": uuid, "code": code, "expiryDate": expiryDateString.replaceAll('-', '') };
}

class Product {
  String code, name, brand;
  Product({this.code, this.name, this.brand});
  Product.from(Map<String, dynamic> data):
        code = data['code'], name = data['name'], brand = data['brand'];
  Map<String, String> toMap() => { "code": code, "name": name, "brand": brand };
}


class AppModel extends Model {
  final Uuid uuidGenerator = new Uuid();
  final Map<String, InventoryItem> _inventoryItems = new Map();
  final Map<String, Product> _products = new Map();

  DateTime _lastSelectedDate = new DateTime.now();
  String _imagePath;

  List<InventoryItem> get inventoryItems {
    List<InventoryItem> toSort = _inventoryItems.values.toList();
    toSort.sort((item1, item2) => item1.expiryDate.compareTo(item2.expiryDate));
    return toSort;
  }

  AppModel() {
    _initAsync();
    print('Item count: ${inventoryItems.length}');
  }

  void _initAsync() async {
    Directory docDir = await getApplicationDocumentsDirectory();
    Directory imagePickerTmpDir = new Directory(docDir.parent.path + '/tmp');
    _imagePath = imagePickerTmpDir.path;
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
  }

  void addItem(InventoryItem item) {
    _inventoryItems[item.uuid] = item;
    notifyListeners();
  }

  void addProduct(Product product) {
    _products[product.code] = product;
    notifyListeners();
  }

  Product getAssociatedProduct(InventoryItem item) {
    return _products[item.code];
  }

  File getImage(String code) {
    return new File('$_imagePath/$code.jpg');
  }
}