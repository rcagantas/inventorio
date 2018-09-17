import 'package:json_annotation/json_annotation.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:quiver/core.dart';
import 'package:quiver/collection.dart';

part 'definitions.g.dart';

@JsonSerializable()
class InventoryItem
    extends Object
    with _$InventoryItemSerializerMixin
    implements Comparable<InventoryItem>
{
  String uuid;
  String code;
  String expiry;
  String dateAdded;

  InventoryItem({this.uuid, this.code, this.expiry, this.dateAdded});
  factory InventoryItem.fromJson(Map<String, dynamic> json) => _$InventoryItemFromJson(json);

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
}

@JsonSerializable()
class Product
    extends Object
    with _$ProductSerializerMixin
    implements Comparable<Product>
{
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

  @override
  int compareTo(Product other) {
    if (other == null) return 1;
    int compare = this.brand?.compareTo(other.brand ?? '') ?? 0;
    if (compare != 0) return compare;
    compare = this.name?.compareTo(other.name ?? '') ?? 0;
    if (compare != 0) return compare;
    compare = this.variant?.compareTo(other.variant ?? '') ?? 0;
    return compare;
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
  Map<String, Product> productDictionary;
  TreeSet<InventoryItem> itemTree = new TreeSet();
  static Map<String, Product> masterProductDictionary = {};

  InventorySet(this.details) :
        productDictionary = {}
  {
    itemTree = new TreeSet(comparator: (item1, item2) {
      int compare = item1.compareTo(item2);
      if (compare != 0) return compare;

      Product product1 = getAssociatedProduct(item1.code);
      Product product2 = getAssociatedProduct(item2.code);
      if (product1 != null && product2 != null)
        return product1.compareTo(product2);

      return item1.code.compareTo(item2.code);
    });
  }

  String _searchFilter;
  set filter(String f) => _searchFilter = f?.trim()?.toLowerCase();

  List<InventoryItem> get items {
    return itemTree.where((item) {
      Product product = getAssociatedProduct(item.code);
      bool test = (_searchFilter == null
        || (product?.brand?.toLowerCase()?.contains(_searchFilter) ?? false)
        || (product?.name?.toLowerCase()?.contains(_searchFilter) ?? false)
        || (product?.variant?.toLowerCase()?.contains(_searchFilter) ?? false)
      );
      return test;
    }).toList();
  }

  Product  getAssociatedProduct(String code) {
    Product product = productDictionary.containsKey(code)
        ? productDictionary[code]
        : masterProductDictionary[code];

    return product;
  }
}