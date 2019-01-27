import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:logging/logging.dart';
import 'dart:math' as math;

class NotifiedItem {
  final InventoryItem item;
  final int modifier;
  int get scheduleId => '${item.uuid}/$modifier'.hashCode % ((math.pow(2, 31)) - 1);
  NotifiedItem(this.item, this.modifier);
}

class SchedulingBloc {
  final _log = Logger('SchedulingBloc');
  final _notifier = Injector.getInjector().get<FlutterLocalNotificationsPlugin>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  final _notifiedItems = Map<int, NotifiedItem>();

  SchedulingBloc() {
    _notifier.initialize(
      InitializationSettings(
        AndroidInitializationSettings('icon'),
        IOSInitializationSettings()
      ),
      onSelectNotification: (inventoryId) {
        _repo.changeCurrentInventory(inventoryId);
      },
    );

    _notifier.cancelAll().then((_) {
      _log.info('Resetting schedules.');
      _notifiedItems.clear();
      _repo.userUpdateStream
        .debounce(Duration(milliseconds: 30))
        .listen((userAccount) {
          var scheduledItemCount = _notifiedItems.length;
          _scheduleItemIfNeeded(userAccount);
          Future.delayed(Duration(seconds: 2), () {
            if (scheduledItemCount != _notifiedItems.length) {
              _log.info('Scheduled ${_notifiedItems.length} items');
            }
          });
      });
    });
  }

  void _scheduleItemIfNeeded(UserAccount userAccount) {
    userAccount.knownInventories.forEach((inventoryId) {
      _repo.getItemListObservable(inventoryId)
        .listen((items) {

          _notifiedItems.removeWhere((index, notified) {
            if (notified.item.inventoryId == inventoryId && !items.contains(notified.item)) {
              _repo.getProductFuture(notified.item.inventoryId, notified.item.code).then((product) {
                _log.info('Cancelling [${notified.scheduleId}] '
                    '${notified.modifier}-day notification for ${product.brand ?? ''} ${product.name ?? ''}');
                _notifier.cancel(notified.scheduleId);
              });
              return true;
            }
            return false;
          });

          items.where((item) => item.expiryDate.compareTo(DateTime.now()) > 0).forEach((item) {
            _repo.getProductFuture(item.inventoryId, item.code).then((product) {
              _scheduleNotification(item, product, item.weekNotification);
              _scheduleNotification(item, product, item.monthNotification);
            });
          });

        });
    });
  }

  void _scheduleNotification(InventoryItem item, Product product, DateTime notificationDate)  {
    var _notificationDetails = Injector.getInjector().get<NotificationDetails>();

    Duration difference = item.expiryDate.difference(notificationDate);
    if (notificationDate.compareTo(DateTime.now()) <= 0) { return; }

    String title = '${product.brand ?? ''} ${product.name ?? ''} ${product.variant ?? ''}';
    String message = 'is about to expire within ${difference.inDays} days on ${item.year} ${item.month} ${item.day}';

    NotifiedItem notifiedItem = NotifiedItem(item, difference.inDays);
    _notifiedItems.putIfAbsent(notifiedItem.scheduleId, () {
      _notifier.schedule(notifiedItem.scheduleId, '$title', '$message',
          notificationDate, _notificationDetails, payload: item.inventoryId).then((_) {
        _log.info('Alerting [${notifiedItem.scheduleId}] $title on $notificationDate');
      });
      return notifiedItem;
    });
  }
}