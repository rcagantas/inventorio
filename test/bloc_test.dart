import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';

class MockRepositoryBloc extends Mock implements RepositoryBloc {
  final _userUpdate = BehaviorSubject<UserAccount>();
  Observable<UserAccount> get userUpdateStream => _userUpdate.stream;
  Function(UserAccount) get userUpdateSink => _userUpdate.sink.add;
  @override void dispose() => _userUpdate.close();
}

void main() {
  Injector.getInjector().map<RepositoryBloc>((_) => MockRepositoryBloc(), isSingleton: true);

  RepositoryBloc _mockRepo;
  InventoryBloc _bloc;

  Map<String, List<InventoryItem>> inventoryData;
  Map<String, InventoryDetails> inventoryDetail;
  Map<String, UserAccount> userData;

  void setupData() {
    inventoryData = {
      'inv_1': [
        InventoryItem(uuid: 'item_11', code: 'product_1', expiry: '2018-12-25T01:22:05.142157', dateAdded: '2018-12-25'),
        InventoryItem(uuid: 'item_12', code: 'product_2', expiry: '2018-12-25T01:22:05.142157', dateAdded: '2018-12-25')
      ],
      'inv_2': [
        InventoryItem(uuid: 'item_21', code: 'product_1', expiry: '2018-12-25T01:22:05.142157', dateAdded: '2018-12-25'),
        InventoryItem(uuid: 'item_22', code: 'product_2', expiry: '2018-12-25T01:22:05.142157', dateAdded: '2018-12-25'),
        InventoryItem(uuid: 'item_23', code: 'product_1', expiry: '2018-12-25T01:22:05.142157', dateAdded: '2018-12-25'),
      ]
    };
    inventoryDetail = {
      'inv_1': InventoryDetails(uuid: 'inv_1', name: 'Inventory 1', createdBy: 'user_999'),
      'inv_2': InventoryDetails(uuid: 'inv_2', name: 'Inventory 2', createdBy: 'user_888')
    };
    userData = {
      'user_999': UserAccount('user_999', 'inv_1')
        ..knownInventories = ['inv_1', 'inv_2']
        ..displayName = 'User 999'
        ..isSignedIn = true
    };
  }

  void setup({withUser: 'user_999',}) {
    setupData();
    _mockRepo = Injector.getInjector().get<RepositoryBloc>();
    reset(_mockRepo);

    when(_mockRepo.signIn()).thenAnswer((inv) {
      _mockRepo.userUpdateSink(withUser == null? RepositoryBloc.unsetUser: userData[withUser]);
    });

    when(_mockRepo.getItemListObservable(any)).thenAnswer((inv) {
      String inventoryId = inv.positionalArguments[0];
      return Observable.just(inventoryData[inventoryId]);
    });

    when(_mockRepo.getInventoryDetailObservable(any)).thenAnswer((inv) {
      String inventoryId = inv.positionalArguments[0];
      return Observable.just(inventoryDetail[inventoryId]);
    });

    when(_mockRepo.changeCurrentInventory(any)).thenAnswer((inv) {
      InventoryDetails detail = inv.positionalArguments[0];
      userData[withUser].currentInventoryId = detail.uuid;
      _mockRepo.userUpdateSink(userData[withUser]);
    });

    _bloc = InventoryBloc();
  }

  test('No user has empty items', () {
    setup(withUser: null);
    verifyNever(_mockRepo.getItemListObservable(any));
  });

  test('User 999 has 2 items', () {
    setup();
    expectLater(_bloc.selectedStream, emits(inventoryData['inv_1']));
  });

  test('User 999 selects inventory inv_2', () {
    setup();
    _bloc.actionSink(Action(Act.ChangeInventory, inventoryDetail['inv_2']));
    expect(_bloc.selectedStream, emitsInOrder([
      inventoryData['inv_1'],
      inventoryData['inv_2']
    ]));
  });
}
