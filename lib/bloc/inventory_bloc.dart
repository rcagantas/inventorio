import 'package:logging/logging.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:rxdart/rxdart.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';

enum Act {
  SignIn, SignOut,
  AddInventory, ChangeInventory, UpdateInventory, UnsubscribeInventory,
  RemoveItem, AddUpdateItem, AddUpdateProduct,
  SetSearchFilter, ToggleSort,
}

enum SortType { DateAdded, Alpha, DateExpiry }

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

  final _sortAction = BehaviorSubject<SortType>();
  Function(SortType) get sortTypeSink => _sortAction.sink.add;
  Observable<SortType> get sortTypeStream => _sortAction.stream;
  SortType _sortingType;

  String _searchFilter;

  List<InventoryItem> Function(List<InventoryItem> itemList) _mutator
    = (List<InventoryItem> itemList) => itemList;

  final _selected = BehaviorSubject<List<InventoryItem>>();
  Function(List<InventoryItem>) get selectedSink => _selected.sink.add;
  Observable<List<InventoryItem>> get selectedStream => _selected.stream.map(_mutator);

  InventoryBloc() {
    _sortingType = SortType.DateExpiry;

    _mutator = (List<InventoryItem> itemList) {
      switch (_sortingType) {
        case SortType.DateAdded: itemList.sort(_dateAddedComparator); break;
        case SortType.DateExpiry: itemList.sort(_expiryComparator); break;
        case SortType.Alpha: itemList.sort(_productComparator); break;
        default: itemList.sort();
      }

      if (_searchFilter == '' || _searchFilter == null) return itemList;
      return itemList.where(_filter).toList();
    };

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
        case Act.ChangeInventory: _handleInventorySelection(action.payload); break;
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

  void _handleInventorySelection(String uuid) {
    if (uuid == '') _populateAllItems();
    else if (_repo.getCachedUser().currentInventoryId == uuid) { // must reset from populate all
      _populateSelectedItems(_repo.getCachedUser());
    }
    else _repo.changeCurrentInventory(uuid);
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

  SortType nextSortType() {
    var index = (_sortingType.index + 1) % SortType.values.length;
    return SortType.values[index];
  }

  void _toggleSort() {
    _sortingType = nextSortType();
    _log.info('Sorting with $_sortingType');
    sortTypeSink(_sortingType);
    _selected.take(1).single.then(selectedSink);
  }

  void _setSearchFilter(String filter) {
    if (filter == _searchFilter) return;
    _searchFilter = filter;
    _log.info('Search filter: $_searchFilter');
  }

  bool _filter(InventoryItem item) {
    _searchFilter = _searchFilter?.trim();
    Product product = _repo.getCachedProduct(item.inventoryId, item.code);
    bool test = (_searchFilter == '' || _searchFilter == null
      ||  (product?.brand?.toLowerCase()?.contains(_searchFilter) ?? false)
      || (product?.name?.toLowerCase()?.contains(_searchFilter) ?? false)
      || (product?.variant?.toLowerCase()?.contains(_searchFilter) ?? false)
    );
    return test;
  }

  void _populateSelectedItems(UserAccount userAccount) {
    _repo.getItemListObservable(userAccount.currentInventoryId)
      .listen((data) {
        selectedSink(data);

        _listenToProductUpdates(data)
          .listen((productList) {
            if (productList.length > 0) {
              _log.info('Finished updating product details. Updating list.');
              selectedSink(data);
            }
          });
      });
  }

  void _populateAllItems() {
    _log.info('Trying to get all items');
    var inventoryList = _repo.getCachedUser().knownInventories;
    var futures = inventoryList.map((inventoryId) => _repo.getItemListObservable(inventoryId).take(1).single);
    Future.wait(futures).then((listOfList) {
      var allItems = listOfList.expand((l) => l).toList();
      _log.info('All items: ${allItems.length}');
      selectedSink(allItems);
    });
  }

  void _cleanUp() {
    selectedSink([]);
  }

  void dispose() async {
    _actions.close();
    _selected.close();
    _sortAction.close();
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