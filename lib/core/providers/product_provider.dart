
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/models/product.dart';
import 'package:inventorio/core/providers/auth_provider.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';

final productImageFilePathProvider = StateProvider.family<String, String>((ref, code) => '');

class ProductNotifier extends StateNotifier<Product> {
  final Ref ref;
  final Item item;

  ProductNotifier(Product state, this.item, this.ref) : super(state);

  void setLatest(Product product) { this.state = product; }
}

final productProvider = StateNotifierProvider.family<ProductNotifier, Product, Item>((ref, item) {
  return ProductNotifier(
    Product(code: item.code, name: null, brand: null, variant: null, imageUrl: null),
    item, ref);
});

final productStreamProvider = StreamProvider.family<Product, Item>((ref, item) async * {
  final store = ref.read(pluginsProvider).store;
  final auth = ref.watch(authProvider);
  if (auth == null) return;

  final localStream = store
    .collection('inventory')
    .doc(item.inventoryId)
    .collection('productDictionary')
    .doc(item.code)
    .snapshots();

  final globalStream = store
      .collection('productDictionary')
      .doc(item.code)
      .snapshots();

  Product extractProduct(Map<String, dynamic> map) {
    Product product = Product.fromJson(map);
    ref.read(productProvider(item).notifier).setLatest(product);
    return product;
  }

  await for (final element in localStream) {
    if (element.exists && element.data() != null) {
      /// product in local dictionary
      yield extractProduct(element.data()!);
    } else {
      await for (final element in globalStream) {
        if (element.exists && element.data() != null) {
          /// product in global dictionary
          yield extractProduct(element.data()!);
        } else {
          /// product not in dictionaries
          yield extractProduct({ 'code': item.code });
        }
      }
    }
  }
});