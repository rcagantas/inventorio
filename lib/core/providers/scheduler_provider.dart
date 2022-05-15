
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/providers/plugins_provider.dart';
import 'package:inventorio/core/providers/product_provider.dart';
import 'package:logger/logger.dart';
import 'package:quiver/core.dart';

import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@immutable
class Scheduler {
  final Ref ref;
  Logger get log => ref.read(pluginsProvider).logger;
  FlutterLocalNotificationsPlugin get notificationsPlugin => ref.read(pluginsProvider).notificationsPlugin;

  static const threadId = 'com.rcagantas.inventorio.scheduled.notifications';
  final androidNotificationDetails = new AndroidNotificationDetails(
    threadId,
    'Inventorio Expiration Notification',
    channelDescription: 'Notification 7 and 30 days before expiry',
  );
  final iosNotificationDetails = new IOSNotificationDetails(
    threadIdentifier: threadId
  );


  Scheduler(this.ref) {
    tz.initializeTimeZones();
  }

  Future<void> schedule(Item item, int offset) async {
    final product = await ref.watch(productStreamProvider(item).future);
    final notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails
    );

    final expiryDate = DateTime.parse(item.expiry!);
    final localTimeZone = await FlutterNativeTimezone.getLocalTimezone();
    final alarmDate = expiryDate.subtract(Duration(days: offset));
    final now = Clock().now();
    if (alarmDate.compareTo(now) < 0) return;

    log.i('scheduling ${product.name} on $alarmDate with tz $localTimeZone');
    await notificationsPlugin.zonedSchedule(
      hashObjects([item.uuid, item.expiry, offset]),
      '${product.brand} ${product.name}'.trim(),
      'is about to expire within $offset days on ${DateFormat.MMM().format(expiryDate)} ${expiryDate.day}',
      tz.TZDateTime.from(alarmDate, tz.getLocation(localTimeZone)),
      notificationDetails,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
      payload: item.inventoryId
    );
  }

  bool hasValidDate(String expiry) {
    try {
      DateTime.parse(expiry);
    } catch (e) {
      return false;
    }
    return true;
  }

  Future<void> scheduleNotifications(List<Item> itemList) async {
    final expiring = itemList
      .where((item) => hasValidDate(item.expiry!))
      .where((item) =>
        DateTime.parse(item.expiry!).subtract(Duration(days: 7)).compareTo(Clock().now()) > 0 ||
        DateTime.parse(item.expiry!).subtract(Duration(days: 30)).compareTo(Clock().now()) > 0)
      .toList();

    final maxLen = expiring.length < 10? expiring.length : 10;
    for (final item in expiring.sublist(0, maxLen)) {
      await schedule(item, 7);
      await schedule(item, 30);
    }
  }

  Future<void> cancelNotifications() async {
    log.i('cancelling all notifications');
    await notificationsPlugin.cancelAll();
  }

  Future<void> cancelItem(Item item) async {
    log.i('cancelling notification for ${item.uuid}');
    await notificationsPlugin.cancel(hashObjects([item.uuid, item.expiry, 7]));
    await notificationsPlugin.cancel(hashObjects([item.uuid, item.expiry, 30]));
  }
}

final schedulerProvider = StateProvider<Scheduler>((ref) => Scheduler(ref));