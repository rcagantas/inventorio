import 'dart:async';
import 'package:logging/logging.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/inventory_repository.dart';
import 'data/definitions.dart';

class InventoryEntry {
  final String barcode;
  final DateTime expiry;
  InventoryEntry({this.barcode, this.expiry});
}

class InventoryItemEx extends InventoryItem {
  String inventoryId;
  InventoryItemEx({InventoryItem item, this.inventoryId})
      : super(uuid: item.uuid, code: item.code, expiry: item.expiry, dateAdded: item.dateAdded);
}

class InventoryBloc {
  final _log = Logger('InventoryBloc');
  final _inventoryRepository = Injector.getInjector().get<InventoryRepository>();
  
  final _entry = StreamController<InventoryEntry>();
  final _items = StreamController<List<InventoryItemEx>>.broadcast();
  final _products = StreamController<Map<String, Product>>.broadcast();
  final _inventory = StreamController<InventoryDetails>.broadcast();

  Function(InventoryEntry) get newEntry => _entry.sink.add;
  Stream<List<InventoryItemEx>> get allItems => _items.stream;
  Stream<InventoryDetails> get currentInventory => _inventory.stream;

  InventoryBloc() {

    _inventoryRepository.getUserAccountObservable()
      .where((userAccount) => userAccount != null)
      .listen((userAccount) {
        _log.info('Account changes ${userAccount.toJson()}');
        _updateInventory(userAccount);
        _updateInventoryList(userAccount);
      });

    _inventoryRepository.signIn();
  }

  void _updateInventory(UserAccount userAccount) {
    _inventoryRepository.getInventoryDetails(userAccount.currentInventoryId)
        .then((inventoryDetails) => _inventory.add(inventoryDetails));
  }

  void _updateInventoryList(UserAccount userAccount) {
    Future.wait(userAccount.knownInventories.map((inventoryId) async {
      var items = await _inventoryRepository.getItems(inventoryId);
      return items.map((item) => InventoryItemEx(item: item, inventoryId: inventoryId)).toList();
    })).then((collection) {
      var flattened = collection.expand((l) => l)
          .where((i) => i.inventoryId == userAccount.currentInventoryId)
          .toList();
      flattened.sort((a, b) => a.daysFromToday.compareTo(b.daysFromToday));
      _items.add(flattened);
    });
  }

  void dispose() async {
    _entry.close();
    _items.close();
    _products.close();
    _inventory.close();
  }
}