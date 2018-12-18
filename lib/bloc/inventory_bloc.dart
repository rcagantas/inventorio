import 'package:logging/logging.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:rxdart/rxdart.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';

class InventoryItemEx extends InventoryItem {
  String inventoryId;
  InventoryItemEx({InventoryItem item, this.inventoryId})
      : super(uuid: item.uuid, code: item.code, expiry: item.expiry, dateAdded: item.dateAdded);
}

class InventoryDetailsEx extends InventoryDetails {
  int currentCount;
  bool isSelected;
  InventoryDetailsEx(InventoryDetails details, this.currentCount, this.isSelected)
      : super(uuid: details.uuid, name: details.name, createdBy: details.createdBy);
}

class InventoryBloc {
  final _log = Logger('InventoryBloc');
  final _repo = Injector.getInjector().get<RepositoryBloc>();

  final _items = BehaviorSubject<List<InventoryItemEx>>();
  final _inventory = BehaviorSubject<InventoryDetails>();
  final _detailMap = BehaviorSubject<List<InventoryDetailsEx>>();

  Observable<List<InventoryItemEx>> get itemStream => _items.stream;
  Observable<InventoryDetails> get inventoryStream => _inventory.stream;
  Observable<List<InventoryDetailsEx>> get detailsStream => _detailMap.stream;

  InventoryBloc() {

    _repo.userAccountStream
      .where((userAccount) => userAccount != null)
      .listen((userAccount) {
        _log.info('Account changes ${userAccount.toJson()}');
        _updateInventory(userAccount);
        _updateInventoryList(userAccount);
      });

    _repo.signIn();
  }

  void _updateInventory(UserAccount userAccount) {
    _repo.getInventoryDetails(userAccount.currentInventoryId)
        .then((inventoryDetails) => _inventory.add(inventoryDetails));
  }

  void _updateInventoryList(UserAccount userAccount) async {
    var details = List<InventoryDetailsEx>();

    for (var inventoryId in userAccount.knownInventories) {
      var items = await _repo.getItems(inventoryId);
      var itemEx = items.map((item) => InventoryItemEx(item: item, inventoryId: inventoryId)).toList();
      if (inventoryId == userAccount.currentInventoryId) {
        itemEx.sort((a, b) => a.daysFromToday.compareTo(b.daysFromToday));
        _items.sink.add(itemEx);
      }

      var detail = await _repo.getInventoryDetails(inventoryId);
      details.add(InventoryDetailsEx(detail, items.length, inventoryId == userAccount.currentInventoryId));
    }
    _detailMap.sink.add(details);
  }

  void dispose() async {
    _items.close();
    _inventory.close();
    _detailMap.close();
  }

  void changeCurrentInventory(String uuid) {
    _repo.changeCurrentInventory(uuid);
  }
}