import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:simple_permissions/simple_permissions.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(new StateManagerWidget(new MyApp()));

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Inventorio', // Doesn't seem to do anything - RC
      theme: new ThemeData(primarySwatch: Colors.blue,),
      home: new ListingsPage(),
    );
  }
}

class Product {
  String code, name, brand, imageFileName;
  @override String toString() { return '($code, $name, $brand, $imageFileName)'; }
}

class InventoryItem {
  static Uuid uuidGen = new Uuid();
  String uuid = uuidGen.v4();
  String code;
  DateTime expiryDate;
  InventoryItem({this.code, this.expiryDate}) { print('adding $uuid'); }
  String get expiryDateString => expiryDate?.toIso8601String()?.substring(0, 10) ?? 'No Expiry Date';
  @override String toString() { return '($code, $expiryDate)'; }
}

/// the only purpose is to propagate changes to entire tree
class AppStateWidget extends InheritedWidget {
  final StateManager stateManager;
  AppStateWidget({this.stateManager, child}): super(child: child);
  @override bool updateShouldNotify(InheritedWidget oldWidget) => true;
}

/// the only purpose is to contain the entire widget tree
class StateManagerWidget extends StatefulWidget {
  final Widget child;
  StateManagerWidget(this.child);
  @override State<StateManagerWidget> createState() => new StateManager();
}

/// holds and manages the app state
class StateManager extends State<StateManagerWidget> {
  final List<InventoryItem> inventoryItems = new List();
  final Map<String, Product> products = new Map();
  final Map<String, File> imageMap = new Map();

  DateTime lastSelectedDate = new DateTime.now();

  @override
  void initState() {
    _requestPermissions();
    _cleanupTemporaryCameraFiles();
    super.initState();
  }

  void _requestPermissions() async {
    bool hasCameraPermission = await SimplePermissions.checkPermission(Permission.Camera);
    if (!hasCameraPermission) await SimplePermissions.requestPermission(Permission.Camera);
  }

  void _cleanupTemporaryCameraFiles() async {
    Directory docDir = await getApplicationDocumentsDirectory();
    Directory imagePickerTmpDir = new Directory(docDir.parent.path + '/tmp');
    imagePickerTmpDir
        .list()
        .where((f) => f.path.contains('image_picker'))
        .forEach((f) {
          print('deleting ${f.path}');
          f.delete();
        });
  }

  void removeItemAtIndex(int index) {
    setState(() { inventoryItems.removeAt(index); });
  }

  Future<DateTime> getExpiryDate(BuildContext context) async {
    DateTime expiryDate = lastSelectedDate;
    try {
       expiryDate = await showDatePicker(
          context: context,
          initialDate: lastSelectedDate,
          firstDate: lastSelectedDate,
          lastDate: lastSelectedDate.add(new Duration(days: 365 * 5))
      );
      print('Setting Expiry Date: [$expiryDate]');
    } catch (e) {
      print('Unknown exception $e');
    }
    return expiryDate;
  }

  void addProduct(BuildContext context, String code, Product product) {
    setState(() {
      print('Adding product [$product]');
      products.putIfAbsent(code, () => product);
    });
  }

  void addItem(InventoryItem item) {
    setState(() {
      print('Adding inventory [$item]');
      inventoryItems.add(item);
    });
  }

  Future<InventoryItem> addItemFlow(BuildContext context) async {
    String code = await BarcodeScanner.scan();
    if (code == null) return null;

    DateTime expiryDate = await getExpiryDate(context);

    if (!products.containsKey(code)) {
      Product product = await Navigator.push(
          context,
          new MaterialPageRoute(
            builder: (context) => new AddProductPage(code: code),
          )
      );
      if (product == null) return null;
    }

    InventoryItem inventoryItem = new InventoryItem(code: code, expiryDate: expiryDate,);
    addItem(inventoryItem);
    return inventoryItem;
  }

  Product getAssociatedProduct(InventoryItem item) {
    return products[item.code];
  }

  void addImage(File file) {
    imageMap.putIfAbsent(file.path, () => file);
  }

  static StateManager of(BuildContext context) {
    return (context.inheritFromWidgetOfExactType(AppStateWidget) as AppStateWidget).stateManager;
  }

  @override Widget build(BuildContext context) => new AppStateWidget(stateManager: this, child: widget.child);
}

class InventoryItemTile extends StatelessWidget {
  final int index;
  InventoryItemTile(this.index);

  @override
  Widget build(BuildContext context) {
    final StateManager state = StateManager.of(context);
    final InventoryItem item = state.inventoryItems[index];
    final Product product = state.getAssociatedProduct(item);

    return new Dismissible(
      key: new ObjectKey(state.inventoryItems[index].uuid),
      child: new ListTile(
        leading: new CircleAvatar(
          backgroundImage: new FileImage(state.imageMap[product.imageFileName]),
        ),
        title: new Text(product.name),
        subtitle: new Text(product.brand),
        trailing: new Text(item.expiryDateString),
      ),
      onDismissed: (direction) { state.removeItemAtIndex(index); },
    );
  }
}

class ListingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final StateManager state = StateManager.of(context);

    return new Scaffold(
      appBar: new AppBar(title: new Text('Inventorio'),),
      body: ListView.builder(
        itemCount: state.inventoryItems.length,
        itemBuilder: (BuildContext context, int index) => new InventoryItemTile(index),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () async { state.addItemFlow(context); },
        child: new Icon(Icons.add_a_photo),
      ),
    );
  }
}

class AddProductPage extends StatefulWidget {
  final String code;
  AddProductPage({this.code});
  @override State<AddProductPage> createState() =>
      new AddProductPageStage();
}

class AddProductPageStage extends State<AddProductPage> {
  final Product product = new Product();

  @override
  Widget build(BuildContext context) {
    final StateManager state = StateManager.of(context);

    return new Scaffold(
      appBar: new AppBar(title: new Text('Add New Product')),
      body: new Center(
        child: new ListView(
          children: <Widget>[
            new ListTile(
              title: new Text('${widget.code}'),
            ),
            new ListTile(
              title: new TextField(
                onChanged: (s) => product.name = s.trim(),
                decoration: new InputDecoration(
                  hintText: 'Name'
                ),
              ),
            ),
            new ListTile(
              title: new TextField(
                onChanged: (s) => product.brand = s.trim(),
                decoration: new InputDecoration(
                  hintText: 'Brand'
                ),
              ),
            ),
            new ListTile(
              title: new RaisedButton(
                onPressed: () async {
                  File file  = await ImagePicker.pickImage(source: ImageSource.camera);
                  print('Setting image file [$file]');
                  product.imageFileName = file.path;
                  state.addImage(file);
                },
                color: Theme.of(context).accentColor,
                child: new Text('Add Image'),
              ),
            )
          ],
        )
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () {
          product.code = widget.code;
          state.addProduct(context, widget.code, product);
          Navigator.pop(context, product);
        },
      ),
    );
  }
}
