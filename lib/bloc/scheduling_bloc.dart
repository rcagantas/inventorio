import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:logging/logging.dart';
import 'package:quiver/core.dart';

void schedulerIsolate(Map<String, dynamic> params) {
  int notificationId = params['notificationId'];
  InventoryItem item = params['item'];
  Product product = params['product'];
  DateTime notificationDate = params['notificationDate'];
}

class NotificationKey {
  final InventoryItem item;
  final int modifier;
  NotificationKey(this.item, this.modifier);
  @override int get hashCode => hash2(item, modifier);
  @override
  bool operator ==(other) {
    return other is NotificationKey
      && this.item == other.item
      && this.modifier == other.modifier;
  }
}

class SchedulingBloc {
  final _log = Logger('SchedulingBloc');
  final _notifications = Injector.getInjector().get<FlutterLocalNotificationsPlugin>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  final Map<NotificationKey, int> _scheduledNotifications = {};

  SchedulingBloc() {
    _log.info('Scheduling Bloc');

    _notifications.initialize(
      InitializationSettings(
        AndroidInitializationSettings('icon'),
        IOSInitializationSettings()
      ),
      onSelectNotification: (inventoryId) {
        _repo.changeCurrentInventory(inventoryId);
      },
    );

    _repo.userUpdateStream
      .debounce(Duration(milliseconds: 300))
      .listen((userAccount) {
        _log.info('Resetting schedules.');
        _notifications.cancelAll().then((_) {
          _scheduledNotifications.clear();
          _scheduleItemIfNeeded(userAccount);
        });
      });
  }

  DateTime _expiryPatch(InventoryItem item, DateTime expiry) {
    DateTime added = item.dateAdded != null
        ? DateTime.parse(item.dateAdded.substring(0, 19).replaceAll('-', '').replaceAll(':', ''))
        : DateTime.now();
    expiry = expiry.add(Duration(hours: added.hour, minutes: added.minute + 1));
    return expiry;
  }

  NotificationKey _hashNotificationKey(InventoryItem item, int modifier) {
    return NotificationKey(item, modifier);
  }

  int _hashNotificationId(NotificationKey key) {
    //return item.hashCode % ((2^31) - 1);
    return _scheduledNotifications.containsKey(key)
      ? _scheduledNotifications[key]
      : _scheduledNotifications.length + 1;
  }

  void _scheduleItemIfNeeded(UserAccount userAccount) {
    userAccount.knownInventories.forEach((inventoryId) {
      _repo.getItemListObservable(inventoryId)
        .debounce(Duration(milliseconds: 300))
        .listen((items) {

          _scheduledNotifications.removeWhere((key, id) {
            bool shouldRemove = !items.contains(key.item);
            if (shouldRemove) {
              _log.info('Cancelling notification for ${key.item.uuid} on modifier ${key.modifier}');
              _notifications.cancel(id);
            }
            return shouldRemove;
          });

          items.where((item) => item.expiryDate.compareTo(DateTime.now()) > 0).forEach((item) async {
            Product product = await _repo.getProductFuture(item.inventoryId, item.code);

            NotificationKey weekKey = _hashNotificationKey(item, 7);
            int weekId = _hashNotificationId(weekKey);
            _scheduledNotifications.putIfAbsent(weekKey, () {
              var log = _scheduleNotification(weekId, item, product, _expiryPatch(item, item.weekNotification));
              if (log != '') _log.info('$log');
              return weekId;
            });

            NotificationKey monthKey = _hashNotificationKey(item, 30);
            int monthId = _hashNotificationId(monthKey);
            _scheduledNotifications.putIfAbsent(monthKey, () {
              var log = _scheduleNotification(monthId, item, product, _expiryPatch(item, item.monthNotification));
              if (log != '') _log.info('$log');
              return monthId;
            });

          });
        });
    });
  }

  String _scheduleNotification(int notificationId, InventoryItem item, Product product, DateTime notificationDate) {
    var _notificationDetails = Injector.getInjector().get<NotificationDetails>();

    if (notificationDate.compareTo(DateTime.now()) <= 0) { return ''; }
    String title = '${product.brand ?? ''} ${product.name ?? ''} ${product.variant ?? ''}';
    Duration difference = notificationDate.difference(item.expiryDate);
    String message = 'is about to expire within ${difference.inDays} days on ${item.year} ${item.month} ${item.day}';

    _notifications.schedule(notificationId, '$title', '$message', notificationDate,
        _notificationDetails, payload: item.inventoryId);
    return 'Alerting $title on $notificationDate';
  }
}