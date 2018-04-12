import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:simple_permissions/simple_permissions.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

const double TILE_HEIGHT = 80.0;

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
  InventoryItem({this.code, this.expiryDate});
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
          lastDate: lastSelectedDate.add(new Duration(days: 365 * 10))
      );
      print('Setting Expiry Date: [$expiryDate]');
    } catch (e) {
      print('Unknown exception $e');
    }
    return expiryDate;
  }

  void addProduct(BuildContext context, String code, Product product) {
    setState(() { products[code] = product; });
  }

  void addItem(InventoryItem item) {
    setState(() {
      print('Adding inventory [$item]');
      inventoryItems.add(item);
      inventoryItems.sort((item1, item2) => item1.expiryDate.compareTo(item2.expiryDate));
    });
  }

  Future<InventoryItem> addItemFlow(BuildContext context) async {
    String code = await BarcodeScanner.scan(); setState(() {});
    if (code == null) return null;

    DateTime expiryDate = await getExpiryDate(context);
    if (expiryDate == null) return null;

    if (!products.containsKey(code)) {
      Product product = await Navigator.push(
        context,
        new MaterialPageRoute(
          builder: (context) => new ProductPage(code: code),
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

class SquareImage extends StatelessWidget {
  final double side;
  final String imageFileName;
  SquareImage({this.side = TILE_HEIGHT, this.imageFileName});

  @override
  Widget build(BuildContext context) {
    final StateManager state = StateManager.of(context);
    return state.imageMap[imageFileName] == null?
      new Container(
        width: side,
        height: side,
        child: new FlutterLogo(),
      ):
      new Container(
        width: side,
        height: side,
        decoration: new BoxDecoration(
          image: new DecorationImage(
            image: new FileImage(state.imageMap[imageFileName]),
            fit: BoxFit.cover,
          ),
          border: new Border.all(color: Colors.white, width: 2.0),
        ),
      );
  }
}

class InventoryItemTile extends StatelessWidget {
  final int index;
  InventoryItemTile(this.index);

  @override
  Widget build(BuildContext context) {
    final StateManager state = StateManager.of(context);
    final InventoryItem item = state.inventoryItems[index];
    final Product product = state.getAssociatedProduct(item);

    Color expiryColorScale(InventoryItem item) {
      DateTime today = new DateTime.now();
      Duration duration = item.expiryDate?.difference(today) ?? new Duration(days: 0);
      if (duration.inDays < 30) return Colors.redAccent;
      else if (duration.inDays < 90) return Colors.yellowAccent;
      return Colors.greenAccent;
    }

    return new Dismissible(
      background: new Container(
        color: Colors.deepOrangeAccent,
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Icon(Icons.delete),
            new Text('Remove', textScaleFactor: 1.0,),
          ],
        ),
      ),
      secondaryBackground: new Container(
        color: Colors.lightBlueAccent,
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            new Text('Edit Product', textScaleFactor: 1.0,),
            new Icon(Icons.edit),
          ],
        ),
      ),
      onDismissed: (direction) {
        switch(direction) {
          case DismissDirection.startToEnd: state.removeItemAtIndex(index); break;
          default: Navigator.push(
            context,
            new MaterialPageRoute(
              builder: (context) => new ProductPage(code: item.code, product: product),
            )
          );
          // need to change uuid so that dismiss works without actually dismissing
          item.uuid = InventoryItem.uuidGen.v4();
        }
      },
      key: new ObjectKey(item.uuid),
      child: new Row(
        children: <Widget>[
          new SquareImage(imageFileName: product.imageFileName,),
          new Expanded(
            flex: 2,
            child: new Column(
              children: <Widget>[
                new Text(product.name, textScaleFactor: 1.2,),
                new Text(product.brand),
              ],
            ),
          ),
          new Expanded(
            child: new Text(
              item.expiryDateString,
              style: new TextStyle(
                fontWeight: FontWeight.bold,
              ),
              textScaleFactor: 1.0,
            ),
          ),
          new Container(
            height: TILE_HEIGHT,
            width: 5.0,
            color: expiryColorScale(item),
          ),
          new Container(
            height: TILE_HEIGHT,
            width: 2.0,
          )
        ],
      ),
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

class ProductPage extends StatefulWidget {
  final String code;
  final Product product;
  ProductPage({this.code, this.product});
  @override State<ProductPage> createState() => new ProductPageState();
}

class ProductPageState extends State<ProductPage> {
  Product product = new Product();

  @override
  Widget build(BuildContext context) {
    final StateManager state = StateManager.of(context);
    product = widget.product ?? product;

    return new Scaffold(
      appBar: new AppBar(title:
        new Text(
          widget.product == null? 'Add New Product': 'Edit Product'
        )
      ),
      body: new Center(
        child: new ListView(
          children: <Widget>[
            new ListTile(
              title: new Text('${widget.code}'),
            ),
            new ListTile(
              title: new TextField(
                controller: new TextEditingController(text: product.name),
                onChanged: (s) => product.name = s.trim(),
                decoration: new InputDecoration(
                  hintText: 'Name'
                ),
              ),
            ),
            new ListTile(
              title: new TextField(
                controller: new TextEditingController(text: product.brand),
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
                  setState(() {
                    product.imageFileName = file.path;
                  });
                  state.addImage(file);
                },
                color: Theme.of(context).accentColor,
                child: new Text('Add Image'),
              ),
            ),
            new ListTile(
              title: new Center(
                child: new SquareImage(side: 200.0, imageFileName: product.imageFileName,)
              ),
            )
          ],
        )
      ),
      floatingActionButton: new FloatingActionButton(
        child: new Icon(Icons.add),
        onPressed: () {
          product.code = widget.code;
          state.addProduct(context, widget.code, product);
          Navigator.pop(context, product);
        },
      ),
    );
  }
}
