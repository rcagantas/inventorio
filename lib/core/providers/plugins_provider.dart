
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/providers/action_sink_provider.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class Plugins {
  final FirebaseAuth auth;
  final FirebaseFirestore store;
  final FirebaseStorage storage;
  final Uuid uuid;
  final Logger logger;
  final FlutterLocalNotificationsPlugin notificationsPlugin;

  Plugins({
    required this.auth,
    required this.store,
    required this.storage,
    required this.uuid,
    required this.logger,
    required this.notificationsPlugin
  });
}

var pluginsProvider = Provider((ref) {
  FlutterLocalNotificationsPlugin notificationsPlugin = new FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  final IOSInitializationSettings initializationSettingsIOS = IOSInitializationSettings(onDidReceiveLocalNotification: (id, title, body, payload) => {},);
  final MacOSInitializationSettings initializationSettingsMacOS = MacOSInitializationSettings();
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
    macOS: initializationSettingsMacOS
  );

  notificationsPlugin.initialize(initializationSettings, onSelectNotification: (inventoryId) async {
    await ref.read(actionSinkProvider).selectInventory(inventoryId!);
  });

  return Plugins(
    auth: FirebaseAuth.instance,
    store: FirebaseFirestore.instance,
    storage: FirebaseStorage.instance,
    uuid: Uuid(),
    logger: Logger(printer: SimplePrinter(colors: false)),
    notificationsPlugin: notificationsPlugin
  );
});