import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventorio/flat/inventory_app.dart';
import 'package:inventorio/inventory_app2.dart';

void main() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) => runApp(InventoryApp2()));
}
