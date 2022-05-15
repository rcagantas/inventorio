import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inventorio/view/auth/auth_gate.dart';
import 'package:inventorio/view/inventory/edit/inventory_edit_page.dart';
import 'package:inventorio/view/inventory/inventory_page.dart';
import 'package:inventorio/view/item/expiry/expiry_page.dart';
import 'package:inventorio/view/user/profile_page.dart';
import 'package:inventorio/view/scan/scan_page.dart';
import 'package:inventorio/view/product/edit/edit_product_page.dart';

import 'firebase_options.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting(Platform.localeName, '');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,);
  FlutterNativeSplash.remove();
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Inventorio',
      routes: {
        '/': (context) => AuthGate(),
        '/settings': (context) => InventoryPage(),
        '/profile': (context) => ProfilePage(),
        '/expiry': (context) => ExpiryPage(),
        '/scan': (context) => ScanPage(),
        '/edit': (context) => EditProductPage(),
        '/inventory': (context) => InventoryEditPage(),
      },
      theme: ThemeData(
        fontFamily: 'Montserrat',
        primaryColor: Colors.blue.shade700,
        accentColor: Colors.blue.shade600,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        fontFamily: 'Montserrat',
        accentColor: Colors.blue.shade500,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
    );
  }
}
