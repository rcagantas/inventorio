import 'dart:io';

import 'package:logging/logging.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:rxdart/rxdart.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';

enum Act {
  SignIn,
  SignOut,
  AddInventory,
  ChangeInventory,
  UpdateInventory,
  UnsubscribeInventory,
  RemoveItem,
  AddUpdateItem,
  AddUpdateProduct,
  SetSearchFilter,
  ToggleSort,
}

enum SortType {
  Alpha,
  DateAdded,
  DateExpiry
}

class Action {
  final Act act;
  final dynamic payload;
  Action(this.act, this.payload);
}

class InventoryBloc {
  final _log = Logger('InventoryBloc');
  final _repo = Injector.getInjector().get<RepositoryBloc>();

  final _actions = BehaviorSubject<Action>();
  Function(Action) get actionSink => _actions.sink.add;

  final _selected = BehaviorSubject<List<InventoryItem>>();
  Function(List<InventoryItem>) get selectedSink => _selected.sink.add;
  Observable<List<InventoryItem>> get selectedStream => _selected.stream;

  final _details = BehaviorSubject<List<InventoryDetails>>();
  Function(List<InventoryDetails>) get detailSink => _details.sink.add;

  final _sortType = BehaviorSubject<SortType>();
  Function(SortType) get sortTypeSink => _sortType.sink.add;
  Observable<SortType> get sortTypeStream => _sortType.stream;
  SortType sortType;

  InventoryBloc() {
    sortType = SortType.DateExpiry;
    _repo.userUpdateStream
      .listen((userAccount) async {
        if (userAccount != null) {
          _populateSelectedItems(userAccount);
        }
      });

    _actions.listen((action) {
      switch (action.act) {
        case Act.SignIn: _repo.signIn(); break;
        case Act.SignOut: _cleanUp(); _repo.signOut(); break;
        case Act.ChangeInventory: _repo.changeCurrentInventory(action.payload); break;
        case Act.RemoveItem: _repo.removeItem(action.payload); break;
        case Act.AddUpdateItem: _repo.updateItem(action.payload); break;
        case Act.AddUpdateProduct: _repo.updateProduct(action.payload); break;
        case Act.UnsubscribeInventory: _repo.unsubscribeFromInventory(action.payload); break;
        case Act.UpdateInventory: _repo.updateInventory(action.payload); break;
        case Act.AddInventory: _repo.addInventory(action.payload); break;
        case Act.SetSearchFilter: _setSearchFilter(action.payload); break;
        case Act.ToggleSort: _toggleSort(); break;
        default: _log.warning('Action ${action.payload} NOT IMPLEMENTED'); break;
      }
    });

    _repo.signIn();
  }

  int _itemAndProductComparator(InventoryItem item1, InventoryItem item2) {
    int compare = item1.compareTo(item2);
    return compare != 0 ? compare: _productComparator(item1, item2);
  }

  int _productComparator(InventoryItem item1, InventoryItem item2) {
    Product product1 = _repo.getCachedProduct(item1.code);
    Product product2 = _repo.getCachedProduct(item2.code);
    int compare = product1.compareTo(product2);
    return compare != 0? compare : item1.compareTo(item2);
  }

  int _dateAddedComparator(InventoryItem item1, InventoryItem item2) {
    var added1 = item1.dateAdded ?? '';
    var added2 = item2.dateAdded ?? '';
    return added2.compareTo(added1);
  }

  void _updateSelected(List<InventoryItem> data) {
    data = data.where(_filter).toList();
    switch (sortType) {
      case SortType.Alpha: data.sort(_productComparator); break;
      case SortType.DateAdded: data.sort(_dateAddedComparator); break;
      case SortType.DateExpiry: data.sort(_itemAndProductComparator); break;
      default: data.sort();
    }
    selectedSink(data);
  }

  void _toggleSort() {
    var index = (sortType.index + 1) % SortType.values.length;
    sortType = SortType.values[index];
    _repo.getItemListFuture().then(_updateSelected);
    sortTypeSink(sortType);
  }

  String _searchFilter;
  void _setSearchFilter(String filter) {
    if (filter == _searchFilter) return;
    _searchFilter = filter;
    _repo.getItemListFuture().then(_updateSelected);
  }

  bool _filter(InventoryItem item) {
    Product product = _repo.getCachedProduct(item.code);
    bool test = (_searchFilter == null || _searchFilter == ''
      || (product?.brand?.toLowerCase()?.contains(_searchFilter) ?? false)
      || (product?.name?.toLowerCase()?.contains(_searchFilter) ?? false)
      || (product?.variant?.toLowerCase()?.contains(_searchFilter) ?? false)
    );
    return test;
  }

  void _populateSelectedItems(UserAccount userAccount) {
    _repo.getItemListObservable(userAccount.currentInventoryId)
      .debounce(Duration(milliseconds: 300))
      .listen(_updateSelected);
  }

  void _cleanUp() {
    selectedSink([]);
  }

  void dispose() async {
    _actions.close();
    _selected.close();
    _details.close();
    _sortType.close();
  }
}