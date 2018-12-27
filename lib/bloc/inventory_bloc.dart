import 'package:logging/logging.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:rxdart/rxdart.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';

enum Action {
  SignIn,
  SignOut,
  ChangeInventory,
  UpdateInventory,
  UnsubscribeInventory
}

class ActionEvent {
  final Action act;
  final Map<String, dynamic> payload;
  ActionEvent(this.act, this.payload);
}

class InventoryBloc {
  final _log = Logger('InventoryBloc');
  final _repo = Injector.getInjector().get<RepositoryBloc>();

  final _items = BehaviorSubject<List<InventoryItem>>();
  final _detail = BehaviorSubject<List<InventoryDetails>>();
  final _actions = BehaviorSubject<ActionEvent>();

  UserAccount _currentUser;

  Observable<List<InventoryItem>> get itemStream => _items.stream;
  Observable<List<InventoryDetails>> get detailStream => _detail.stream;
  Function(ActionEvent) get actionSink => _actions.sink.add;
  Observable<UserAccount> get userAccountStream => _repo.userUpdateStream;

  InventoryBloc() {

    _repo.userUpdateStream
      .listen((userAccount) {
        if (userAccount != null) {
          _updateCurrent(userAccount);
          _processInventoryItems(userAccount);
        } else {
          _cleanUp();
        }
      });

    _actions.listen((action) {
      switch (action.act) {
        case Action.SignIn: _repo.signIn(); break;
        case Action.SignOut: _repo.signOut(); _cleanUp(); break;
        case Action.ChangeInventory: _repo.changeCurrentInventory(_currentUser, InventoryDetails.fromJson(action.payload)); break;
        case Action.UnsubscribeInventory: _repo.unsubscribeFromInventory(_currentUser, InventoryDetails.fromJson(action.payload)); break;
        default: _log.warning('Action ${action.payload} NOT IMPLEMENTED'); break;
      }
    });

    _repo.signIn();
  }

  void _cleanUp() {
    _items.sink.add([]);
    _detail.sink.add([]);
  }

  void _updateCurrent(UserAccount userAccount) async {
    _currentUser = userAccount;
    String inventoryId = userAccount.currentInventoryId;
    _repo.getItems(inventoryId).then((items) async {
      items.sort((a, b) => a.daysFromToday.compareTo(b.daysFromToday));
      _items.sink.add(items);
    });
  }

  void _processInventoryItems(UserAccount userAccount) async {
    Stopwatch stopwatch = Stopwatch()..start();
    List<InventoryDetails> details = await Future.wait(userAccount.knownInventories.map((id) => _repo.getInventoryDetails(id)));
    List<List<InventoryItem>> collection = await Future.wait(userAccount.knownInventories.map((id) => _repo.getItems(id)));

    var total = 0;
    for (int i = 0; i < userAccount.knownInventories.length; i++) {
      total += collection[i].length;
      if (details[i] != null) {
        details[i]
          ..currentCount = collection[i].length
          ..isSelected = userAccount.currentInventoryId == details[i].uuid;
      }
    }

    stopwatch.stop();
    _log.info('Finished processing $total inventory items in ${stopwatch.elapsedMilliseconds} ms');
    _detail.sink.add(details);
  }

  void dispose() async {
    _items.close();
    _detail.close();
    _actions.close();
  }
}