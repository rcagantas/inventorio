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

enum Action {
  SignIn,
  SignOut,
  ChangeInventory,
  UpdateInventory
}

class ActionEvent {
  final Action act;
  final Map<String, dynamic> payload;
  ActionEvent(this.act, this.payload);
}

class InventoryBloc {
  final _log = Logger('InventoryBloc');
  final _repo = Injector.getInjector().get<RepositoryBloc>();

  final _items = BehaviorSubject<List<InventoryItemEx>>();
  final _detail = BehaviorSubject<List<InventoryDetailsEx>>();
  final _actions = BehaviorSubject<ActionEvent>();

  Observable<List<InventoryItemEx>> get itemStream => _items.stream;
  Observable<List<InventoryDetailsEx>> get detailStream => _detail.stream;
  Function(ActionEvent) get actionSink => _actions.sink.add;
  Observable<UserAccountEx> get userAccountStream => _repo.userUpdateStream;

  InventoryBloc() {

    _repo.userUpdateStream
      .where((userAccount) => userAccount != null)
      .listen((userAccount) {
        _updateCurrent(userAccount);
        _processInventoryItems(userAccount);
      });

    _actions.listen((action) {
      switch (action.act) {
        case Action.SignIn: _repo.signIn(); break;
        case Action.SignOut: _cleanUp(); break;
        case Action.ChangeInventory: _repo.changeCurrentInventoryFromDetail(InventoryDetails.fromJson(action.payload)); break;
        default: _log.warning('Action ${action.payload} NOT IMPLEMENTED'); break;
      }
    });

    _repo.signIn();
  }

  void _cleanUp() {
    _repo.signOut();
    _items.sink.add([]);
    _detail.sink.add([]);
  }

  void _updateCurrent(UserAccount userAccount) async {
    String inventoryId = userAccount.currentInventoryId;
    _repo.getItems(inventoryId).then((items) async {
      var itemEx = items.map((item) => InventoryItemEx(item: item, inventoryId: inventoryId)).toList();
      itemEx.sort((a, b) => a.daysFromToday.compareTo(b.daysFromToday));
      _items.sink.add(itemEx);
    });
  }

  void _processInventoryItems(UserAccount userAccount) async {
    List<InventoryDetails> details = await Future.wait(userAccount.knownInventories.map((id) => _repo.getInventoryDetails(id)));
    List<List<InventoryItem>> collection = await Future.wait(userAccount.knownInventories.map((id) => _repo.getItems(id)));
    List<InventoryDetailsEx> detailExs = [];

    var total = 0;
    for (int i = 0; i < userAccount.knownInventories.length; i++) {
      total += collection[i].length;
      detailExs.add(InventoryDetailsEx(details[i], collection[i].length, userAccount.currentInventoryId == details[i].uuid));
    }
    _detail.sink.add(detailExs);

    _log.info('Finished processing $total inventory items. $details}');
  }

  void dispose() async {
    _items.close();
    _detail.close();
    _actions.close();
  }
}