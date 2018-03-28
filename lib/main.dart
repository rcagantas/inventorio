import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:simple_permissions/simple_permissions.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:flutter/services.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Inventorio', // Doesn't seem to do anything - RC
      theme: new ThemeData(primarySwatch: Colors.blue,),
      home: new MyHomePage(title: 'Inventorio'), // This sets the header - RC
    );
  }
}

class MyHomePage extends StatefulWidget {
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  final String title;
  MyHomePage({Key key, this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class InventoryItem {
  static final uuidGenerator = new Uuid();
  final String uuid = uuidGenerator.v4();
  var label, expirationDate, barCode;
  InventoryItem({this.label = '', this.expirationDate = '', this.barCode = ''});
}

class _MyHomePageState extends State<MyHomePage> {
  final List<InventoryItem> inventoryItems = new List();

  @override
  void initState() {
    super.initState();
    requestAndSetPermissions();
  }

  void requestAndSetPermissions() async {
    bool res = await SimplePermissions.checkPermission(Permission.Camera);
    if (!res) await SimplePermissions.requestPermission(Permission.Camera);
  }

  void _addItem(BuildContext context) async {
    String snack = 'Adding new item';
    String barCode = '';
    try {
      barCode = await BarcodeScanner.scan();
    } on PlatformException catch(e) {
      snack = 'Unknown error: $e';
      if (e.code == BarcodeScanner.CameraAccessDenied) {
        snack = 'User did not grant camera access permission';
      }
    } on FormatException {
      snack = 'User returned using back-button';
    } catch (e) {
      snack = 'Unknown error: $e';
    }

    setState(() {
      inventoryItems.add(new InventoryItem(
          label: 'Optional Label',
          expirationDate: 'Expiration Date',
          barCode: barCode,
      ));

      Scaffold.of(context).showSnackBar(new SnackBar(content: new Text(snack)));
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called.
    return new Scaffold(
      appBar: new AppBar(title: new Text(widget.title),),
      body: new ListView.builder(
        itemCount: inventoryItems.length,
        itemBuilder: (BuildContext context, int index) => new ListTile(
          leading: new CircleAvatar(),
          title: new Text(inventoryItems[index].label),
          subtitle: new Text(inventoryItems[index].uuid),
          trailing: new Text(inventoryItems[index].expirationDate),
        ),
      ),
      floatingActionButton: new Builder(
        builder: (BuildContext context) {
          return new FloatingActionButton(
            onPressed: () { _addItem(context); },
            tooltip: 'Add new inventory item',
            child: new Icon(Icons.add),
          );
        }
      ),
    );
  }
}
