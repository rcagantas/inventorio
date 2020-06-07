import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:inventorio/inventory_app2.dart';

//void main() {
//  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
//      .then((_) => runApp(InventoryApp2()));
//}

Future<Null> _reportError(dynamic error, dynamic stackTrace) async {
  print(stackTrace);
}

dynamic main() async {
  FlutterError.onError = (FlutterErrorDetails details) async {
    await _reportError(details.exception, details.stack);
  };

  Isolate.current.addErrorListener(new RawReceivePort((dynamic pair) async {
    await _reportError(
      (pair as List<String>).first,
      (pair as List<String>).last,
    );
  }).sendPort);

  if (kReleaseMode) {
    runZonedGuarded<Future<Null>>(() {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
          .then((_) => runApp(InventoryApp2()));
      return null;
    }, (error, stackTrace) async {
      await _reportError(error, stackTrace);
    });
  } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
        .then((_) => runApp(InventoryApp2()));
  }
}