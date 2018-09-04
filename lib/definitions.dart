import 'package:json_annotation/json_annotation.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:quiver/core.dart';

part 'definitions.g.dart';

@JsonSerializable()
class InventoryItem extends Object with _$InventoryItemSerializerMixin {
  String uuid;
  String code;
  String expiry;

  InventoryItem({this.uuid, this.code, this.expiry});
  factory InventoryItem.fromJson(Map<String, dynamic> json) => _$InventoryItemFromJson(json);

  DateTime get expiryDate => DateTime.parse(expiry.replaceAll('-', ''));
  String get year => DateFormat.y().format(expiryDate);
  String get month => DateFormat.MMM().format(expiryDate);
  String get day => DateFormat.d().format(expiryDate);
  int get daysFromToday => expiryDate.difference(DateTime.now()).inDays;
  DateTime get weekNotification => expiryDate.subtract(Duration(days: 7));
  DateTime get monthNotification => expiryDate.subtract(Duration(days: 30));
}

@JsonSerializable()
class Product extends Object with _$ProductSerializerMixin {
  String code;
  String name;
  String brand;
  String variant;
  String imageUrl;

  Product({this.code, this.brand, this.name, this.variant, this.imageUrl});
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
        imageUrl == other.imageUrl
    ;
  }
}

@JsonSerializable()
class InventoryDetails extends Object with _$InventoryDetailsSerializerMixin {
  String uuid;
  String name;
  String createdBy;
  InventoryDetails({@required this.uuid, this.name, this.createdBy});
  factory InventoryDetails.fromJson(Map<String, dynamic> json) => _$InventoryDetailsFromJson(json);

  @override String toString() => '$name   $uuid';
}

@JsonSerializable()
class UserAccount extends Object with _$UserAccountSerializerMixin {
  List<String> knownInventories = List();
  String userId;
  String currentInventoryId;

  UserAccount(this.userId, this.currentInventoryId) {
    knownInventories.add(this.currentInventoryId);
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) =>
      _$UserAccountFromJson(json);

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
  Map<String, InventoryItem> itemMap;
  Map<String, Product> productDictionary;
  static Map<String, Product> masterProductDictionary = {};

  InventorySet(this.details)
      : itemMap = {},
        productDictionary = {};

  String _searchFilter;
  set filter(String f) => _searchFilter = f?.trim()?.toLowerCase();

  List<InventoryItem> _items = [];
  get items {
    if (_items.isEmpty || _items.length != itemMap.length) {
      _items = itemMap?.values?.toList() ?? [];
      _items.sort((item1, item2) {
        if (item1.expiryDate == item2.expiryDate) {
          Product product1 = getAssociatedProduct(item1.code);
          Product product2 = getAssociatedProduct(item2.code);
          return product1.toString().compareTo(product2.toString());
        }
        else return item1.expiryDate.compareTo(item2.expiryDate);
      });
    }

    return _items.where((item) {
      Product product = getAssociatedProduct(item.code);
      bool test = (
        _searchFilter == null ||
        (product.brand != null && product.brand.toLowerCase().contains(_searchFilter)) ||
        (product.name != null &&  product.name.toLowerCase().contains(_searchFilter)) ||
        (product.variant != null && product.variant.toLowerCase().contains(_searchFilter))
      );
      return test;
    }).toList();
  }

  Product getAssociatedProduct(String code) {
    Product product = productDictionary.containsKey(code)
        ? productDictionary[code]
        : masterProductDictionary[code];

    return product;
  }

  void itemReset() {
    _items.clear();
  }
}