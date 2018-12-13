
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inventorio/inventory_bloc.dart';
import 'package:inventorio/inventory_repository.dart';
import 'package:inventorio/widgets/listings_page.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';

class InventoryApp2 extends StatefulWidget {
  @override
  _InventoryApp2State createState() => _InventoryApp2State();
}

class _InventoryApp2State extends State<InventoryApp2> {
  final _injector = Injector.getInjector();

  _InventoryApp2State() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((LogRecord rec) {
      var logMessage = '${rec.time}: ${rec.message}';
      print('$logMessage');
    });

    _injector.map<GoogleSignIn>((_) => GoogleSignIn(), isSingleton: true);
    _injector.map<InventoryRepository>((_) => InventoryRepository(), isSingleton: true);
    _injector.map<InventoryBloc>((_) => InventoryBloc(), isSingleton: true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'NotoSans',
        primaryColor: Colors.blue.shade700,
        accentColor: Colors.blue.shade700,
      ),
      title: 'Inventorio',
      home: ListingsPage()
    );
  }

  @override
  void dispose() {
    _injector.get<InventoryBloc>().dispose();
    super.dispose();
  }
}