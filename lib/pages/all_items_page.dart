import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/pages/listings_page.dart';

class AllItemsPage extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();

  @override
  Widget build(BuildContext context) {
    SearchDelegate<InventoryItem> _searchDelegate = InventoryItemSearchDelegate();
    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          StreamBuilder<SortType>(
            initialData: SortType.DateExpiry,
            stream: _bloc.sortTypeStream,
            builder: (context, snap) {
              return IconButton(
                icon: ListingsPage.iconToggle(snap.data),
                onPressed: () async {
                  ListingsPage.showSnackBar(context, _bloc.nextSortType());
                  _bloc.actionSink(Action(Act.ToggleSort, null));
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed:() async { showSearch(context: context, delegate: _searchDelegate); }
          )
        ],
        title: Text('All Items'),
      ),
      body: WillPopScope(
        child: ListingsPage.buildList(context, () => Container(), _bloc.selectedStream),
        onWillPop: () async {
          Future.delayed(Duration(milliseconds: 300), () {
            _bloc.actionSink(Action(Act.SelectAll, false));
          });
          return true;
        },
      ),
    );
  }
}
