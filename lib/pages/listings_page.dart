import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:connectivity/connectivity.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/pages/item_add_page.dart';
import 'package:inventorio/pages/scan_page.dart';
import 'package:inventorio/widgets/user_drawer.dart';
import 'package:inventorio/widgets/widget_factory.dart';

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
    return WidgetFactory.buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _bloc.actionSink(Action(Act.SetSearchFilter, query));
    return WidgetFactory.buildList(context);
  }
}


class ListingsPage extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  final SearchDelegate<InventoryItem> _searchDelegate = InventoryItemSearchDelegate();

  static Icon iconToggle(SortType sortType) {
    switch(sortType) {
      case SortType.DateExpiry: return Icon(Icons.sort);
      case SortType.Alpha: return Icon(Icons.sort_by_alpha);
      case SortType.DateAdded: return Icon(Icons.calendar_today);
    }
    return Icon(Icons.sort);
  }

  static showSortingSnackBar(BuildContext context, SortType sortType) {
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

  void _scanBarcode(BuildContext context) async {
    Navigator.of(context).push<String>(MaterialPageRoute(builder: (context) => ScanPage())).then((code) {
      if (code == null) return;
      code = code.contains('/')? code.replaceAll('/', '#') : code;
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => ItemAddPage(_repo.buildItem(code))));
    });
  }


  final bold = const TextStyle(fontWeight: FontWeight.bold);
  final boldItalic = const TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic);

  Widget _loadingText(bool loading, bool unset) {
    if (loading) return Text('Loading...', style: boldItalic);
    else if (unset) return Text('Sign In With Google', style: bold);
    return Text('Scan Barcode', style: bold, key: ObjectKey('scan_fab_text'),);
  }

  Widget _fabFactory(BuildContext context, UserAccount userAccount) {
    bool loading = userAccount.isLoading;
    bool unset = userAccount.email == '';
    return FloatingActionButton.extended(
      key: ObjectKey('scan_fab'),
      backgroundColor: loading ? Colors.grey : Theme.of(context).accentColor,
      onPressed: () async {
        if (loading) return;
        else if (unset) _repo.signIn();
        else _scanBarcode(context);
      },
      icon: loading || unset
        ? Icon(FontAwesomeIcons.google, key: ObjectKey('loading_fab_icon'))
        : Icon(FontAwesomeIcons.barcode, key: ObjectKey('scan_fab_icon'),),
      label: _loadingText(loading, unset),
    );
  }

  Widget _mainScaffold(BuildContext context, UserAccount userAccount) {
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
                  showSortingSnackBar(context, _bloc.nextSortType());
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
        title: StreamBuilder<InventoryDetails>(
          stream: _repo.getInventoryDetailObservable(userAccount.currentInventoryId),
          builder: (context, detailSnapshot) {
            return detailSnapshot.hasData
              ? Text('${detailSnapshot.data.name}')
              : Text('Current Inventory');
          },
        ),
      ),
      body: WidgetFactory.buildList(context),
      floatingActionButton: _fabFactory(context, userAccount),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      drawer: UserDrawer(),
    );
  }

  Widget _signInScaffold(BuildContext context) {
    var header = <Widget>[];
    var tail = <Widget>[
      ListTile(
        title: Text('Maximize Your Inventory',
          style: TextStyle(fontSize: 20.0),
          textAlign: TextAlign.center,
        ),
      ),
      WidgetFactory.link(context, 'Privacy Policy', 'https://rcagantas.github.io/inventorio/inventorio_privacy_policy.html'),
      StreamBuilder<ConnectivityResult>(
        stream: Connectivity().onConnectivityChanged,
        builder: (context, snap) {
          if (snap.hasData && snap.data == ConnectivityResult.none) {
            return ListTile(title: Text('OFFLINE', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),);
          }
          return SizedBox.shrink();
        },
      ),
    ];
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).scaffoldBackgroundColor, elevation: 0.0,),
      body: WidgetFactory.buildWelcome(header, tail),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _fabFactory(context, UserAccount.userUnset())
    );
  }

  Widget _loadingScaffold(BuildContext context) {
    var header = <Widget>[];
    var tail = <Widget>[];

    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).scaffoldBackgroundColor, elevation: 0.0,),
      body: WidgetFactory.buildWelcome(header, tail),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _fabFactory(context, UserAccount.userLoading()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserAccount>(
      initialData: _repo.getCachedUser(),
      stream: _repo.userUpdateStream,
      builder: (context, snap) {
        if (snap.hasData && !snap.data.isLoading) {
          return snap.data.isSignedIn
              ? _mainScaffold(context, snap.data)
              : _signInScaffold(context);
        }
        return _loadingScaffold(context);
      },
    );
  }
}
