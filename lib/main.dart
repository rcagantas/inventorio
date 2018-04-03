import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:simple_permissions/simple_permissions.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barcode_scan/barcode_scan.dart';

void requestAndSetPermissions() async {
  bool res = await SimplePermissions.checkPermission(Permission.Camera);
  if (!res) await SimplePermissions.requestPermission(Permission.Camera);
}

void main() {
  requestAndSetPermissions();
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
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
  final String title;
  MyHomePage({Key key, this.title}) : super(key: key);
  @override _MyHomePageState createState() => new _MyHomePageState();
}

class InventoryItem {
  static final uuidGenerator = new Uuid();
  final String uuid = uuidGenerator.v4();
  String label, barCode;
  DateTime expirationDate;
  Image image;
  InventoryItem({this.label, this.expirationDate, this.barCode, this.image});

  String get expirationDateString => expirationDate?.toIso8601String()?.substring(0, 10) ?? '';
  String get title => this.label?.toString() ?? this.uuid;
  String get subTitle => this.barCode?.toString() ?? this.uuid;

  Image get displayImage => image == null? Image.asset('resources/images/milo.jpg'): image;
}

class InventoryListItem extends StatelessWidget {
  final InventoryItem inventoryItem;
  InventoryListItem(this.inventoryItem): super();
  @override
  Widget build(BuildContext context) {
    return new ListTile(
//      leading: new CircleAvatar(backgroundImage: inventoryItem.displayImage.image,),
//      title: new Text(inventoryItem.title),
//      subtitle: new Text(inventoryItem.subTitle),
//      trailing: new Text(inventoryItem.expirationDateString),
      title: new Row(
        children: <Widget>[
          new Container(
            height: 100.0, width: 100.0,
            decoration: new BoxDecoration(
              image: new DecorationImage(
                image: inventoryItem.displayImage.image,
                fit: BoxFit.cover,
              ),
            ),
          ),
          new Expanded(
            child: new Column(
              children: <Widget>[
                new Text(inventoryItem.title, textScaleFactor: 1.2,),
                new Text(inventoryItem.subTitle, textScaleFactor: 0.5,),
              ],
            ),
          ),
        ],
      ),
      trailing: new Text(inventoryItem.expirationDateString),
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  DateTime lastPickedDate = new DateTime.now();
  final List<InventoryItem> inventoryItems = new List();

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called.
    return new Scaffold(
      appBar: new AppBar(title: new Text(widget.title),),
      body: new ListView.builder(
        itemCount: inventoryItems.length,
        itemBuilder: (BuildContext context, int index) =>
          new Dismissible(
            key: new ObjectKey(inventoryItems[index].uuid),
            child: new InventoryListItem(inventoryItems[index]),
            onDismissed: (direction) {
              setState(() => inventoryItems.remove(inventoryItems[index]));
            },
          ),
      ),
      floatingActionButton: new Builder(
        builder: (BuildContext context) {
          return new FloatingActionButton(
            onPressed: () async {
              InventoryItem inventoryItem = await Navigator.push(
                context,
                new MaterialPageRoute(builder: (context) => new _AddItemPage()));
              setState(() {
                if (inventoryItem != null) inventoryItems.add(inventoryItem);
              });
            },
            tooltip: 'Add new inventory item',
            child: new Icon(Icons.add),
          );
        }
      ),
    );
  }
}

class _AddItemPage extends StatefulWidget {
  @override _AddItemPageState createState() => new _AddItemPageState();
}

class _AddItemPageState extends State<_AddItemPage> {
  DateTime lastPickedDate = new DateTime.now();
  InventoryItem inventoryItem = new InventoryItem();

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(title: new Text('Add new item')),
      body: new ListView(
        children: <Widget>[
          new ListTile(
            leading: const Icon(Icons.add_a_photo),
            title: new FlatButton(
              onPressed: () async {
                var file = await ImagePicker.pickImage(source: ImageSource.camera);
                setState(() { inventoryItem.image = new Image.file(file); });
              },
              child: new AspectRatio(
                aspectRatio: 16.0/9.0,
                child: new Container(
                  decoration: new BoxDecoration(
                    image: new DecorationImage(
                      fit: BoxFit.fitWidth,
                      alignment: FractionalOffset.center,
                      image: inventoryItem.displayImage.image
                    )
                  ),
                ),
              ),
            ),
          ),
          new ListTile(
            leading: const Icon(Icons.today),
            title: new RaisedButton(
              child: new Text(
                inventoryItem.expirationDate != null?
                inventoryItem.expirationDate.toIso8601String().substring(0, 10):
                'Expiration Date',
              ),
              onPressed: () async {
                var expirationDate = await showDatePicker(context: context,
                  initialDate: lastPickedDate,
                  firstDate: lastPickedDate,
                  lastDate: lastPickedDate.add(const Duration(days: 365*5)));
                setState(() {
                  inventoryItem.expirationDate = expirationDate;
                });
              }
            ),
          ),
          new ListTile(
            leading: const Icon(Icons.label),
            title: new TextField(
              decoration: new InputDecoration(hintText: 'Label'),
              onChanged: (value) {
                setState(() { inventoryItem.label = value; });
              },
            )
          ),
          new ListTile(
            leading: const Icon(Icons.confirmation_number),
            title: new RaisedButton(
              child: new Text(inventoryItem?.barCode ?? 'Barcode'),
              onPressed: () async {
                var barCode = await BarcodeScanner.scan();
                setState(() { inventoryItem.barCode = barCode; });
              },
            ),
          ),
        ],
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () { Navigator.of(context).pop(inventoryItem); },
        child: new Icon(Icons.add_circle_outline),
      ),
    );
  }
}