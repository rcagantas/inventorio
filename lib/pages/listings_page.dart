import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/pages/item_add_page.dart';
import 'package:inventorio/widgets/item_card.dart';
import 'package:inventorio/pages/scan_page.dart';
import 'package:inventorio/widgets/user_drawer.dart';

class InventoryItemSearchDelegate extends SearchDelegate<InventoryItem> {
  final _bloc = Injector.getInjector().get<InventoryBloc>();

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          _bloc.actionSink(Action(Act.SetSearchFilter, null));
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        _bloc.actionSink(Action(Act.SetSearchFilter, null));
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return ListingsPage.buildList(context, () => Container(), _bloc.selectedStream);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _bloc.actionSink(Action(Act.SetSearchFilter, query));
    return ListingsPage.buildList(context, () => Container(), _bloc.selectedStream);
  }
}


class ListingsPage extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();

  static Icon iconToggle(SortType sortType) {
    switch(sortType) {
      case SortType.DateExpiry: return Icon(Icons.sort);
      case SortType.Alpha: return Icon(Icons.sort_by_alpha);
      case SortType.DateAdded: return Icon(Icons.calendar_today);
    }
    return Icon(Icons.sort);
  }

  static showSnackBar(BuildContext context, SortType sortType) {
    String message = '';
    switch(sortType) {
      case SortType.DateExpiry: message = 'Sorting by expiration date.'; break;
      case SortType.Alpha: message = 'Sorting by product.'; break;
      case SortType.DateAdded: message = 'Sorting by date added.'; break;
    }

    Scaffold.of(context).showSnackBar(
      SnackBar(duration: Duration(milliseconds: 500), content: Text('$message'),)
    );
  }

  static Widget buildList(BuildContext context, Function whenEmpty, Stream<List<InventoryItem>> stream) {
    return StreamBuilder<List<InventoryItem>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData || snap.data.length == 0) return whenEmpty();
        double textScaleFactor = MediaQuery.of(context).textScaleFactor;
        return ListView.builder(
          itemExtent: ItemCard.BASE_HEIGHT * textScaleFactor,
          itemCount: snap.data?.length ?? 0,
          itemBuilder: (context, index) => ItemCard(snap.data[index]),
        );
      },
    );
  }

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
                icon: iconToggle(snap.data),
                onPressed: () async {
                  showSnackBar(context, _bloc.nextSortType());
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
        title: StreamBuilder<UserAccount>(
          stream: _repo.userUpdateStream,
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return Text('Current Inventory');
            return StreamBuilder<InventoryDetails>(
              stream: _repo.getInventoryDetailObservable(userSnapshot.data.currentInventoryId),
              builder: (context, detailSnapshot) {
                return detailSnapshot.hasData
                  ? Text('${detailSnapshot.data.name}')
                  : Text('Current Inventory');
              },
            );
          },
        ),
      ),
      body: buildList(context, _buildWelcome, _bloc.selectedStream),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          Navigator.of(context).push<String>(MaterialPageRoute(builder: (context) => ScanPage())).then((code) {
            if (code == null) return;
            code = code.contains('/')? code.replaceAll('/', '#') : code;
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => ItemAddPage(_repo.buildItem(code))));
          });
        },
        icon: Icon(FontAwesomeIcons.barcode),
        label: Text('Scan Barcode')
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      drawer: UserDrawer(),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Image.asset('resources/icons/icon.png', width: 150.0, height: 150.0,),
          ListTile(title: Text('Welcome to Inventorio', textAlign: TextAlign.center,)),
          ListTile(title: Text('Scanned items and expiration dates will appear here. ', textAlign: TextAlign.center,)),
          ListTile(title: Text('Scan new items by clicking the button below.', textAlign: TextAlign.center,)),
        ],
      ),
    );
  }
}
