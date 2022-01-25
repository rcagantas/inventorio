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

  List<int> _scheduleIds = [];

  InvSchedulerService({
    this.notificationsPlugin
  });

  void initialize({
    void Function(int id, String title, String body, String payload) onDidReceiveLocalNotification,
    void Function(String payload) onSelectNotification,
  }) {

    // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final IOSInitializationSettings initializationSettingsIOS = IOSInitializationSettings(onDidReceiveLocalNotification: onDidReceiveLocalNotification);
    final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS
    );

    this.notificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);

    this.androidNotificationDetails = AndroidNotificationDetails(
      'com.rcagantas.inventorio.scheduled.notifications',
      'Inventorio Expiration Notification',
      'Notification 7 and 30 days before expiry',
    );

    this.iosNotificationDetails = IOSNotificationDetails();
    this.notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails
    );
  }

  Future<void> clearScheduledTasks() async {
    await notificationsPlugin.cancelAll();
  }

  Future<void> delayedScheduleNotification(InvExpiry expiry, int delayMs) async {
    await Future.delayed(Duration(milliseconds: delayMs), () {
      if (!_scheduleIds.contains(expiry.scheduleId)) {
        scheduleNotification(expiry);
      }
    });
  }

  Future<void> scheduleNotification(InvExpiry expiry) async {
    Stopwatch stopwatch = Stopwatch()..start();
    _scheduleIds.add(expiry.scheduleId);
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