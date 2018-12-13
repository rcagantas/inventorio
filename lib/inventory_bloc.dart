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
  final _repo = Injector.getInjector().get<InventoryRepository>();
  
  final _entry = StreamController<InventoryEntry>();
  final _items = StreamController<List<InventoryItemEx>>();
  final _products = StreamController<Map<String, Product>>();

  Function(InventoryEntry) get newEntry => _entry.sink.add;
  Stream<List<InventoryItemEx>> get allItems => _items.stream;

  InventoryBloc() {
    _repo.getAccount().then((userAccount) async {
      _log.info('Loaded ${userAccount.toJson()}.');

      Future.wait(userAccount.knownInventories.map((inventoryId) async {
        var items = await _repo.getItems(inventoryId);
        return items.map((item) => InventoryItemEx(item: item, inventoryId: inventoryId)).toList();
      })).then((collection) {
        _items.add(collection.expand((l) => l).toList());
      });

    });
  }

  void dispose() async {
    _entry.close();
    _items.close();
    _products.close();
  }
}