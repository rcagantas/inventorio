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
  DateAdded,
  Alpha,
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

  final _sortType = BehaviorSubject<SortType>();
  Function(SortType) get sortTypeSink => _sortType.sink.add;
  Observable<SortType> get sortTypeStream => _sortType.stream;
  SortType _sortingType;

  InventoryBloc() {
    _sortingType = SortType.DateExpiry;
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
        case Act.AddUpdateProduct: {
          Product product = action.payload;
          _repo.updateProduct(product);
          break;
        }
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

  int _productComparator(InventoryItem item1, InventoryItem item2) {
    Product product1 = _repo.getCachedProduct(item1.inventoryId, item1.code);
    Product product2 = _repo.getCachedProduct(item2.inventoryId, item2.code);
    int compare = product1.compareTo(product2);
    return compare != 0? compare : item1.compareTo(item2);
  }

  int _dateAddedComparator(InventoryItem item1, InventoryItem item2) {
    var added1 = item1.dateAdded ?? '';
    var added2 = item2.dateAdded ?? '';
    return added2.compareTo(added1);
  }

  int _expiryComparator(InventoryItem item1, InventoryItem item2) {
    int compare = item1.compareTo(item2);
    if (compare != 0) return compare;

    Product product1 = _repo.getCachedProduct(item1.inventoryId, item1.code);
    Product product2 = _repo.getCachedProduct(item2.inventoryId, item2.code);

    return product1.compareTo(product2);
  }

  void _updateSelected(List<InventoryItem> data) async {
    switch (_sortingType) {
      case SortType.DateAdded: data.sort(_dateAddedComparator); break;
      case SortType.DateExpiry: data.sort(_expiryComparator); break;
      case SortType.Alpha: data.sort(_productComparator); break;
      default: data.sort();
    }
    selectedSink(data);
  }

  SortType nextSortType() {
    var index = (_sortingType.index + 1) % SortType.values.length;
    return SortType.values[index];
  }

  void _toggleSort() {
    _sortingType = nextSortType();
    _repo.getItemListFuture().then(_updateSelected);
    sortTypeSink(_sortingType);
  }

  String _searchFilter;
  void _setSearchFilter(String filter) {
    if (filter == _searchFilter) return;

    _searchFilter = filter;
    _repo.getItemListFuture().then((data) {
      data = data.where(_filter).toList();
      _updateSelected(data);
    });
  }

  bool _filter(InventoryItem item) {
    _searchFilter = _searchFilter?.trim();
    Product product = _repo.getCachedProduct(item.inventoryId, item.code);
    bool test = (_searchFilter == '' || _searchFilter == null
      || (product?.brand?.toLowerCase()?.contains(_searchFilter) ?? false)
      || (product?.name?.toLowerCase()?.contains(_searchFilter) ?? false)
      || (product?.variant?.toLowerCase()?.contains(_searchFilter) ?? false)
    );
    return test;
  }

  void _populateSelectedItems(UserAccount userAccount) {
    _repo.getItemListObservable(userAccount.currentInventoryId)
      .listen((data) {
        _updateSelected(data);

        _listenToProductUpdates(data)
          .listen((productList) {
            if (productList.length > 0) {
              _log.info('Finished updating product details. Updating list.');
              _updateSelected(data);
              _setSearchFilter(_searchFilter);
            }
          });
      });
  }

  void _cleanUp() {
    selectedSink([]);
  }

  void dispose() async {
    _actions.close();
    _selected.close();
    _sortType.close();
  }

  Observable<List<Product>> _listenToProductUpdates(List<InventoryItem> data) {
    var productStreams = data.map((item) {
      return _repo.getProductObservable(item.inventoryId, item.code);
    }).toList();

    if (data.length == 0) return Observable.empty();
    if (data.length == 1) productStreams.add(Observable.empty());
    return Observable.combineLatestList(productStreams);
  }
}