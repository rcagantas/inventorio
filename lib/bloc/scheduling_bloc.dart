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
  var lastKnownUserId = 'unset_user';

  SchedulingBloc() {
    _notifier.initialize(
      InitializationSettings(
        AndroidInitializationSettings('ic_alert'),
        IOSInitializationSettings()
      ),
      onSelectNotification: (inventoryId) {
        _repo.signIn().then((_) {
          _repo.changeCurrentInventory(inventoryId);
        });
        return;
      },
    );
    reloadOnUserConnect();
  }

  void reloadOnUserConnect() {
    _repo.userUpdateStream
      .debounce(Duration(milliseconds: 30))
      .listen((userAccount) {
        var delay = Duration(seconds: 6 + (1 * userAccount.knownInventories.length));
        if (userAccount.isLoading) return;
        else if (userAccount.isSignedIn) {
          if (userAccount.displayName == RepositoryBloc.CACHED_DATA) {
            _log.info('Scheduler: Keeping alerts. Still cached.');
          } else if (userAccount.userId == lastKnownUserId) {
            _scheduleItemIfNeeded(userAccount);
            return;
          } else {
            lastKnownUserId = userAccount.userId;
            _log.info('Scheduler: Signed in. Cancelling notifications and rescheduling');
            _notifier.cancelAll().then((_) {
              _scheduleItemIfNeeded(userAccount);
            });
          }
        } else if (!userAccount.isSignedIn) {
          lastKnownUserId = userAccount.userId;
          _log.info('Scheduler: Signed out. Cancelling notifications');
          _notifier.cancelAll();
        }

        Future.delayed(delay, () {
        _log.info('Scheduler: Scheduled ${_notifiedItems.length} items.');
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
                _log.info('Scheduler: Cancelling [${notified.scheduleId}] '
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

    String title = product.toString();
    String message = 'is about to expire within ${difference.inDays} days on ${item.year} ${item.month} ${item.day}';

    NotifiedItem notifiedItem = NotifiedItem(item, difference.inDays);
    _notifiedItems.putIfAbsent(notifiedItem.scheduleId, () {
      _notifier.schedule(notifiedItem.scheduleId, '$title', '$message',
          notificationDate, _notificationDetails, payload: item.inventoryId).then((_) {
        _log.info('Alerting [${notifiedItem.scheduleId}] $title on $notificationDate');
      }, onError: (error) {
        _log.severe('Failed to schedule [${notifiedItem.scheduleId}] $title on $notificationDate.', error);
      });
      return notifiedItem;
    });
  }
}