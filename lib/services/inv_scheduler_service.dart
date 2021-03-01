import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:inventorio/models/inv_expiry.dart';
import 'package:inventorio/utils/log/log_printer.dart';
import 'package:logger/logger.dart';

class InvSchedulerService {
  final logger = Logger(printer: SimpleLogPrinter('InvSchedulerService'));

  final FlutterLocalNotificationsPlugin notificationsPlugin;
  AndroidNotificationDetails androidNotificationDetails;
  IOSNotificationDetails iosNotificationDetails;
  NotificationDetails notificationDetails;

  InvSchedulerService({
    this.notificationsPlugin
  });

  void initialize({
    void Function(int id, String title, String body, String payload) onDidReceiveLocalNotification,
    void Function(String payload) onSelectNotification,
  }) {

    this.notificationsPlugin.initialize(
      InitializationSettings(
        AndroidInitializationSettings('@mipmap/ic_launcher'),
        IOSInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
          onDidReceiveLocalNotification: onDidReceiveLocalNotification
        )
      ), onSelectNotification: onSelectNotification
    );

    this.androidNotificationDetails = AndroidNotificationDetails(
      'com.rcagantas.inventorio.scheduled.notifications',
      'Inventorio Expiration Notification',
      'Notification 7 and 30 days before expiry',
    );

    this.iosNotificationDetails = IOSNotificationDetails();
    this.notificationDetails = NotificationDetails(
      androidNotificationDetails,
      iosNotificationDetails
    );
  }

  Future<void> clearScheduledTasks() async {
    await notificationsPlugin.cancelAll();
  }

  Future<void> delayedScheduleNotification(InvExpiry expiry, int delayMs) async {
    await Future.delayed(Duration(milliseconds: delayMs), () {
      scheduleNotification(expiry);
    });
  }

  Future<void> scheduleNotification(InvExpiry expiry) async {
    Stopwatch stopwatch = Stopwatch()..start();
    await notificationsPlugin.schedule(
      expiry.scheduleId,
      expiry.title,
      expiry.body,
      expiry.alertDate,
      notificationDetails,
      payload: expiry.inventoryId
    );

    stopwatch.stop();
    logger.i('$expiry [${stopwatch.elapsedMilliseconds} ms]');
  }
}