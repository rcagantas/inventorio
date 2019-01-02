import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:quiver/core.dart';

part 'package:inventorio/data/definitions.g.dart';

@JsonSerializable()
class InventoryItem implements Comparable<InventoryItem>
{
  String uuid;
  String code;
  String expiry;
  String dateAdded;
  String inventoryId;

  InventoryItem({this.uuid, this.code, this.expiry, this.dateAdded, this.inventoryId});
  factory InventoryItem.fromJson(Map<String, dynamic> json) => _$InventoryItemFromJson(json);
  Map<String, dynamic> toJson() => _$InventoryItemToJson(this);

  DateTime get expiryDate => DateTime.parse(expiry.replaceAll('-', ''));
  String get year => DateFormat.y().format(expiryDate);
  String get month => DateFormat.MMM().format(expiryDate);
  String get day => DateFormat.d().format(expiryDate);
  int get daysFromToday => expiryDate.difference(DateTime.now()).inDays;
  DateTime get weekNotification => expiryDate.subtract(Duration(days: 7));
  DateTime get monthNotification => expiryDate.subtract(Duration(days: 30));

  @override
  int compareTo(InventoryItem other) {
    return this.daysFromToday.compareTo(other.daysFromToday);
  }

  @override String toString() { return this.toJson().toString(); }
  @override int get hashCode => hashObjects(this.toJson().values);
  @override bool operator ==(other) => other is InventoryItem
      && this.uuid == other.uuid
      && this.code == other.code
      && this.expiry == other.expiry;
}

@JsonSerializable()
class Product implements Comparable<Product>
{
  String code;
  String name;
  String brand;
  String variant;
  String imageUrl;

  Product({this.code, this.brand, this.name, this.variant, this.imageUrl});
  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);

  @override
  int get hashCode => hashObjects(toJson().values);

  @override
  bool operator ==(other) {
    return other is Product
        && code == other.code
        && name == other.name
        && brand == other.brand
        && variant == other.variant
        && imageUrl == other.imageUrl
    ;
  }

  @override
  int compareTo(Product other) {
    int compare = 0;
    if (other == null) return 1;
    compare = this.name?.compareTo(other.name ?? '') ?? 0;
    if (compare != 0) return compare;
    compare = this.brand?.compareTo(other.brand ?? '') ?? 0;
    if (compare != 0) return compare;
    compare = this.variant?.compareTo(other.variant ?? '') ?? 0;
    return compare;
  }
}

@JsonSerializable()
class InventoryDetails {
  String uuid;
  String name;
  String createdBy;
  @JsonKey(ignore: true) int currentCount;
  @JsonKey(ignore: true) bool isSelected;
  InventoryDetails({@required this.uuid, this.name, this.createdBy});
  factory InventoryDetails.fromJson(Map<String, dynamic> json) => _$InventoryDetailsFromJson(json);
  Map<String, dynamic> toJson() => _$InventoryDetailsToJson(this);

  @override String toString() => '$name   $uuid';
}

@JsonSerializable()
class UserAccount {
  List<String> knownInventories = List();
  String userId;
  String currentInventoryId;
  @JsonKey(ignore: true) String displayName;
  @JsonKey(ignore: true) String email;
  @JsonKey(ignore: true) String imageUrl;
  @JsonKey(ignore: true) bool isSignedIn;

  UserAccount(this.userId, this.currentInventoryId) { knownInventories.add(this.currentInventoryId);}
  factory UserAccount.fromJson(Map<String, dynamic> json) => _$UserAccountFromJson(json);
  Map<String, dynamic> toJson() => _$UserAccountToJson(this);

  @override int get hashCode => hashObjects(toJson().values);

  @override
  bool operator ==(other) {
    return other is UserAccount &&
        knownInventories == other.knownInventories &&
        userId == other.userId &&
        currentInventoryId == other.currentInventoryId;
  }
}

class InventorySet {
  InventoryDetails details;
  Map<String, Product> productDictionary = {};
  List<InventoryItem> _itemList = [];
  static Map<String, Product> masterProductDictionary = {};
  static Map<String, Product> masterProductCache = {};

  Map<String, Uint8List> replacedImage = {};

  int _itemAndProductComparator(InventoryItem item1, InventoryItem item2) {
    int compare = item1.compareTo(item2);
    if (compare != 0) return compare;
    if (getAssociatedProduct(item1.code) != null) {
      return _productComparator(item1, item2);
    }
    return item1.code.compareTo(item2.code);
  }

  int _productComparator(InventoryItem item1, InventoryItem item2) {
    Product product1 = getAssociatedProduct(item1.code);
    Product product2 = getAssociatedProduct(item2.code);
    return product1.compareTo(product2);
  }

  InventorySet(this.details):
        productDictionary = {},
        _itemList = [];

  String _searchFilter;
  set filter(String f) => _searchFilter = f?.trim()?.toLowerCase();

  void itemClear() {
    _itemList.clear();
  }

  void addItem(InventoryItem item) {
    _itemList.add(item);
  }

  bool sortAlpha = false;
  List<InventoryItem> get items {
    _itemList.sort(sortAlpha? _productComparator: _itemAndProductComparator);

    return _itemList.where((item) {
      Product product = getAssociatedProduct(item.code);
      bool test = (_searchFilter == null
        || (product?.brand?.toLowerCase()?.contains(_searchFilter) ?? false)
        || (product?.name?.toLowerCase()?.contains(_searchFilter) ?? false)
        || (product?.variant?.toLowerCase()?.contains(_searchFilter) ?? false)
      );
      return test;
    }).toList();
  }

  Product getAssociatedProduct(String code) {
    Product product;
    if (productDictionary.containsKey(code)) {
      product = productDictionary[code];
    } else if (masterProductDictionary.containsKey(code)) {
      product = masterProductDictionary[code];
    } else if (masterProductCache.containsKey(code)) {
      product = masterProductCache[code];
    }
    return product;
  }
}