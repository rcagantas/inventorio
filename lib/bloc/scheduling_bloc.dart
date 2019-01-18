import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';

class SchedulingBloc {
  final _log = Logger('SchedulingBloc');
  final _notifications = Injector.getInjector().get<FlutterLocalNotificationsPlugin>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  final _notificationDetails = NotificationDetails(
    AndroidNotificationDetails(
      'com.rcagantas.inventorio.scheduled.notifications',
      'Inventorio Expiration Notification',
      'Notification 7 and 30 days before expiry'
    ),
    IOSNotificationDetails()
  );


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
        _notifications.cancelAll();
        _scheduleItemIfNeeded(userAccount);
      });
  }

  DateTime _expiryPatch(InventoryItem item, DateTime expiry) {
    DateTime added = item.dateAdded != null
        ? DateTime.parse(item.dateAdded.substring(0, 19).replaceAll('-', '').replaceAll(':', ''))
        : DateTime.now();
    expiry = expiry.add(Duration(hours: added.hour, minutes: added.minute + 1));
    return expiry;
  }

  int _hashNotification(String uuid, DateTime expiry) {
    return hash('$uuid/${expiry.toIso8601String()}') % ((2^31) - 1);
  }

  void _scheduleItemIfNeeded(UserAccount userAccount) {
    userAccount.knownInventories.forEach((inventoryId) {
      _repo.getItemListObservable(inventoryId)
        .debounce(Duration(milliseconds: 300))
        .listen((items) {
          items.where((item) => item.expiryDate.compareTo(DateTime.now()) > 0).forEach((item) async {
            Product product = await _repo.getProductFuture(item.inventoryId, item.code);

            int weekNotificationId = _hashNotification(item.uuid, item.weekNotification);
            String weekMessage = 'is about to expire within 7 days on ${item.year} ${item.month} ${item.day}';
            _scheduleNotification(weekNotificationId, inventoryId, product, weekMessage, _expiryPatch(item, item.weekNotification));

            int monthNotificationId = _hashNotification(item.uuid, item.monthNotification);
            String monthMessage = 'is about to expire within 30 days on ${item.year} ${item.month} ${item.day}';
            _scheduleNotification(monthNotificationId, inventoryId, product, monthMessage, _expiryPatch(item, item.monthNotification));
          });
        });
    });
  }

  void _scheduleNotification(int notificationId, String inventoryId, Product product, String message, DateTime notificationDate) {
    String brand = product.brand ?? '';
    String name = product.name ?? '';
    String variant = product.variant ?? '';

    if (notificationDate.compareTo(DateTime.now()) <= 0) {
      return;
    }

    _notifications.schedule(
      notificationId,
      '$name $variant',
      '$message',
      notificationDate,
      _notificationDetails,
      payload: inventoryId
    );

    _log.info('Alerting $brand $name $variant on $notificationDate');
  }
}