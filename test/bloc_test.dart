import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';


class MockRepositoryBloc extends Mock implements RepositoryBloc {}

void main() {
  Injector.getInjector().map<RepositoryBloc>((_) => MockRepositoryBloc(), isSingleton: true);

  var _mockRepo;
  var _bloc;
  var _inv1Item1 = InventoryItem(uuid: 'item_1', code: 'product_1', expiry: '2018-12-25T01:22:05.142157', dateAdded: '2018-12-25');
  var _inv1Item2 = InventoryItem(uuid: 'item_2', code: 'product_2', expiry: '2018-12-25T01:22:05.142157', dateAdded: '2018-12-25');

  void _setup({withUser: true,}) {
    _mockRepo = Injector.getInjector().get<RepositoryBloc>();
    reset(_mockRepo);

    when(_mockRepo.userUpdateStream).thenAnswer((inv) {
      var user = UserAccount('user_999', 'inv_1')
        ..displayName = 'User 999'
        ..signedIn = true;
      return withUser ? Observable<UserAccount>.just(user) : Observable<UserAccount>.empty();
    });

    when(_mockRepo.getItems('inv_1')).thenAnswer((inv) {
      return Future.value([_inv1Item1, _inv1Item2,]);
    });

    when(_mockRepo.getInventoryDetails('inv_1')).thenAnswer((inv) {
      return Future.value(
        InventoryDetails(uuid: 'inv_1', name: 'Inventory 1', createdBy: 'user_999')
      );
    });

    _bloc = InventoryBloc();
  }

  test('No user has empty items', () {
    _setup(withUser: false);
    verifyNever(_mockRepo.getItems(any));
  });

  test('User 999 has 2 items', () {
    _setup();
    expectLater(_bloc.itemStream, emits([
      _inv1Item1,
      _inv1Item2
    ]));
  });
}
