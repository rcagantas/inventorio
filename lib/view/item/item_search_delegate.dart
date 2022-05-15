
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/product.dart';
import 'package:inventorio/core/providers/main_items_provider.dart';
import 'package:inventorio/core/providers/product_provider.dart';
import 'package:inventorio/view/item/item_card.dart';

class ItemSearchDelegateBody extends ConsumerWidget {
  final String inventoryId;
  final String query;
  const ItemSearchDelegateBody({Key? key, required this.inventoryId, required this.query}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final items = ref.watch(mainItemsProvider);
    final searched = items.where((item) {
      final Product product = ref.watch(productStreamProvider(item)).value!;
      return query == '' || product.toString().toLowerCase().contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: searched.length,
      itemBuilder: (context, index) => ItemCard(searched[index])
    );
  }
}


class ItemSearchDelegate extends SearchDelegate<String> {
  final String inventoryId;
  ItemSearchDelegate(this.inventoryId);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(onPressed: () => query = '', icon: Icon(Icons.clear))
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(onPressed: () => close(context, ''), icon: Icon(Icons.arrow_back_ios_new));
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ItemSearchDelegateBody(inventoryId: inventoryId, query: query);
  }

}