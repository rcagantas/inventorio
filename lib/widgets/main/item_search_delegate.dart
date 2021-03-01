import 'package:dart_extensions_methods/dart_extensions_methods.dart';
import 'package:flutter/material.dart';
import 'package:inventorio/models/inv_item.dart';
import 'package:inventorio/models/inv_product.dart';
import 'package:inventorio/providers/inv_state.dart';
import 'package:inventorio/widgets/main/item_card.dart';
import 'package:provider/provider.dart';

class ItemSearchDelegate extends SearchDelegate<InvItem> {

  @override
  ThemeData appBarTheme(BuildContext context) {
    var theme = Theme.of(context);
    return theme
    .copyWith(
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: theme.disabledColor
        ),
      ),
      primaryTextTheme: theme.primaryTextTheme,
      textTheme: theme.textTheme.copyWith(
        headline6: theme.textTheme.headline6.copyWith(
          color: theme.primaryTextTheme.headline6.color
        )
      )
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      Consumer<InvState>(
        builder: (context, invState, child) {
          return IconButton(
            icon: const Icon(Icons.clear),
            onPressed: ()  {
              query = '';
            },
          );
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return Consumer<InvState>(
      builder: (context, invState, child) {
        return IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: ()  {
            query = '';
            close(context, null);
          },
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSuggestions(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Consumer<InvState>(
      builder: (context, invState, child) {

        List<InvItem> filtered = invState.selectedInvList().where((element) {
          InvProduct product = invState.getProduct(element.code);

          return query.isNullOrEmpty() || product.stringRepresentation
            .toLowerCase()
            .contains(query.toLowerCase());
        }).toList();

        return ListView.builder(
          itemBuilder: (context, index) {
            InvItem invItem = filtered[index];
            return ItemCard(invItem);
          },
          itemCount: filtered.length
        );
      },
    );
  }
}
