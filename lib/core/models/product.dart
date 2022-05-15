
import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonSerializable()
class Product implements Comparable<Product> {
  final String? code;
  final String? name;
  final String? brand;
  final String? variant;
  final String? imageUrl;

  Product({
    required this.code,
    required this.name,
    required this.brand,
    required this.variant,
    required this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);

  @override
  int compareTo(Product other) {
    final thisString = this.toString();
    final otherString = other.toString();
    return thisString.compareTo(otherString);
  }

  @override
  String toString() {
    return '${this.brand} ${this.name} ${this.variant}'.trim();
  }
}

class ProductBuilder {
  String? code;
  String? name;
  String? brand;
  String? variant;
  String? imageUrl;

  ProductBuilder();
  ProductBuilder.fromProduct(Product product):
    this.code = product.code,
    this.name = product.name,
    this.brand = product.brand,
    this.variant = product.variant,
    this.imageUrl = product.imageUrl;

  Product _build() {
    return Product(
      code: this.code,
      name: this.name?.trim(),
      brand: this.brand?.trim(),
      variant: this.variant?.trim(),
      imageUrl: this.imageUrl
    );
  }

  Product build() {
    if (this.name == null || this.name == '' || this.code == null || this.code == '') {
      throw UnsupportedError('ProductBuilder cannot build with [name, code]: [$name, $code]');
    }
    return _build();
  }

  @override
  String toString() => _build().toString();
}