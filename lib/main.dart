import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';
import 'package:simple_permissions/simple_permissions.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

final Uuid uuidGenerator = new Uuid();

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

class AppPreferences {
  static const double TILE_HEIGHT = 80.0;
  static const double MARGIN = 2.0;
}

class Product {
  String code, name, brand;
  Product({this.code, this.name, this.brand});
  Product.from(Map<String, dynamic> data):
      code = data['code'], name = data['name'], brand = data['brand'];
  Map<String, String> toMap() => { "code": code, "name": name, "brand": brand };
  @override String toString() { return '($code, $name, $brand)'; }
}

class InventoryItem {
  String uuid, code;
  DateTime expiryDate;
  InventoryItem(this.uuid, { this.code, this.expiryDate });
  InventoryItem.from(Map<String, dynamic> data):
    uuid = data['uuid'], code = data['code'], expiryDate = DateTime.parse(data['expiryDate']);

  String get expiryDateString => expiryDate?.toIso8601String()?.substring(0, 10) ?? 'No Expiry Date';

  Map<String, String> toMap() => { "uuid": uuid, "code": code, "expiryDate": expiryDateString.replaceAll('-', '') };
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
  final Map<String, InventoryItem> _inventoryItems = new Map();
  final Map<String, Product> _products = new Map();

  static String _inventoryId;

  Stream<QuerySnapshot> get inventoryStream => _inventoryItemCollection.snapshots;
  CollectionReference get _productCollection => Firestore.instance.collection('inventory').document(_inventoryId).collection('products');
  CollectionReference get _inventoryItemCollection => Firestore.instance.collection('inventory').document(_inventoryId).collection('inventoryItems');

  List<InventoryItem> get inventoryItems {
    List<InventoryItem> toSort = _inventoryItems.values.toList();
    toSort.sort((item1, item2) => item1.expiryDate.compareTo(item2.expiryDate));
    return toSort;
  }

  final Map<String, File> _imageMap = new Map();
  DateTime _lastSelectedDate = new DateTime.now();

  @override
  void initState() {
    _requestPermissions();
    _cleanupTemporaryCameraFiles();
    _ensureSignIn();
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
      .forEach((f) {
        if (f.path.contains('image_picker')) {
          print('Deleting ${f.path}');
          f.delete();
        } else if (f.path.endsWith('.jpg')) {
          print('Loading ${f.path}');
          _imageMap.putIfAbsent(basenameWithoutExtension(f.path), () => f);
        }
      });
  }

  void _ensureSignIn() async {
    DocumentReference currentInventory;
    GoogleSignIn googleSignIn = new GoogleSignIn();
    GoogleSignInAccount user = googleSignIn.currentUser;
    user = user == null ? await googleSignIn.signInSilently() : user;
    user = user == null ? await googleSignIn.signIn() : user;
    print('User: $user');

    var userDocument = await Firestore.instance.collection('users').document(user.id).get();

    if (!userDocument.exists) {
      print('Adding user: $user');

      currentInventory = Firestore.instance.collection('inventory').document();
      currentInventory.setData({
        "createdBy": user.id,
        "createdOn": new DateTime.now().toIso8601String(),
        "shared": false
      });

      Firestore.instance.collection('users').document(user.id).setData({
        "currentInventory": currentInventory.documentID,
        "knownInventory": [currentInventory.documentID]
      });
    } else {
      String currentInventoryId = userDocument.data['currentInventory'];
      currentInventory = Firestore.instance.collection('inventory').document(currentInventoryId);
    }

    _inventoryId = currentInventory.documentID;
    print('Current inventory Id $_inventoryId');
    _productCollection.getDocuments().then((snap) {
      snap.documents.forEach((d) => _products[d.documentID] = new Product.from(d.data));
      _inventoryItemCollection.getDocuments().then((snap) {
        snap.documents.forEach((d) => _inventoryItems[d.documentID] = new InventoryItem.from(d.data));
        setState(() {});
      });
    });
  }

  void removeItem(InventoryItem item) {
    _inventoryItemCollection.document(item.uuid).delete();
    setState(() { _inventoryItems.remove(item.uuid); });
    print('Deleting inventory $item');
  }

  Future<DateTime> getExpiryDate(BuildContext context) async {
    DateTime expiryDate = _lastSelectedDate;
    try {
       expiryDate = await showDatePicker(
          context: context,
          initialDate: _lastSelectedDate,
          firstDate: _lastSelectedDate.subtract(new Duration(days: 1)),
          lastDate: _lastSelectedDate.add(new Duration(days: 365 * 10))
      );
      print('Setting Expiry Date: [$expiryDate]');
    } catch (e) {
      print('Unknown exception $e');
    }
    return expiryDate;
  }

  void addProduct(BuildContext context, Product product) {
    setState(() { _products[product.code] = product; });
    _productCollection.document(product.code).setData(product.toMap());
  }

  void addItem(InventoryItem item) {
    setState(() { _inventoryItems[item.uuid] = item; });
    _inventoryItemCollection.document(item.uuid).setData(item.toMap());
  }

  Future<InventoryItem> addItemFlow(BuildContext context) async {
    String code = await BarcodeScanner.scan(); setState(() {});
    if (code == null) return null;

    DateTime expiryDate = await getExpiryDate(context);
    if (expiryDate == null) return null;

    if (!_products.containsKey(code)) {
      Product product = await Navigator.push(
        context,
        new MaterialPageRoute(
          builder: (context) => new ProductPage(code: code),
        )
      );
      if (product == null) return null;
    }

    InventoryItem inventoryItem = new InventoryItem(uuidGenerator.v4(), code: code, expiryDate: expiryDate,);
    addItem(inventoryItem);
    return inventoryItem;
  }

  Product getAssociatedProduct(InventoryItem item) {
    return _products[item.code];
  }

  void addProductImage(Product product, File file) async {
    if ('${product.code}.jpg' != basename(file.path)) {
      file = await file.rename('${dirname(file.path)}/${product.code}.jpg');
      print('Renamed to ${file.path}');
    }
    setState(() {
      _imageMap.putIfAbsent(product.code, () => file);
    });
  }

  File getImage(String code) {
    print('Trying $code: ${_imageMap[code]}');
    return _imageMap[code];
  }

  static StateManager of(BuildContext context) {
    return (context.inheritFromWidgetOfExactType(AppStateWidget) as AppStateWidget).stateManager;
  }

  @override Widget build(BuildContext context) => new AppStateWidget(stateManager: this, child: widget.child);
}

class SquareImage extends StatelessWidget {
  final double side;
  final File imageFile;
  SquareImage({this.side = AppPreferences.TILE_HEIGHT, this.imageFile});

  @override
  Widget build(BuildContext context) {
    return new Container(
      width: side,
      height: side,
      child: imageFile == null?
        new Icon(
          Icons.camera_alt,
          size: side,
          color: Theme.of(context).buttonColor,
        ):
        null,
      decoration: imageFile == null?
        null :
        new BoxDecoration(
        image: new DecorationImage(
          image: new FileImage(imageFile),
          fit: BoxFit.cover,
        ),
        border: new Border.all(
          color: Theme.of(context).canvasColor,
          width: AppPreferences.MARGIN,
        )
      ),
    );
  }
}

class InventoryItemTile extends StatelessWidget {
  final InventoryItem item;
  InventoryItemTile(this.item);

  @override
  Widget build(BuildContext context) {
    final StateManager state = StateManager.of(context);
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
          case DismissDirection.startToEnd:
            state.removeItem(item);
            Scaffold.of(context).showSnackBar(
              new SnackBar(
                content: new Text('Removed item ${product.name}'),
                action: new SnackBarAction(
                  label: "UNDO",
                  onPressed: () {
                    item.uuid = uuidGenerator.v4();
                    state.addItem(item);
                  },
                )
              )
            );
            break;
          default: Navigator.push(
            context,
            new MaterialPageRoute(
              builder: (context) => new ProductPage(code: item.code, product: product),
            )
          );
          // need to change uuid so that dismiss works without actually dismissing
          item.uuid = uuidGenerator.v4();
        }
      },
      key: new ObjectKey(item.uuid),
      child: new Row(
        children: <Widget>[
          new SquareImage(imageFile: state.getImage(item.code),),
          new Expanded(
            flex: 2,
            child: new Column(
              children: <Widget>[
                new Text(product.brand),
                new Text(product.name, textScaleFactor: 1.3,),
                new Text(item.uuid.substring(0, 8), textScaleFactor: 0.5,)
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
            height: AppPreferences.TILE_HEIGHT,
            width: 5.0,
            color: expiryColorScale(item),
            margin: new EdgeInsets.only(right: AppPreferences.MARGIN),
          ),
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
        itemBuilder: (BuildContext context, int index) => new InventoryItemTile(state.inventoryItems[index]),
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
    product.code = widget.code ?? product.code;

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
              title: new Text('${product.code}'),
            ),
            new ListTile(
              title: new TextField(
                controller: new TextEditingController(text: product.brand),
                onChanged: (s) => product.brand = s.trim(),
                decoration: new InputDecoration(hintText: 'Brand'),
              ),
            ),
            new ListTile(
              title: new TextField(
                controller: new TextEditingController(text: product.name),
                onChanged: (s) => product.name = s.trim(),
                decoration: new InputDecoration(hintText: 'Name'),
              ),
            ),
            new ListTile(
              title: new Container(
                margin: new EdgeInsets.only(top: 20.0),
                child: new Center(
                  child: new FlatButton(
                    onPressed: () async {
                      File file  = await ImagePicker.pickImage(source: ImageSource.camera);
                      state.addProductImage(product, file);
                    },
                    child: new SquareImage(
                      side: 250.0,
                      imageFile: state.getImage(product.code),
                    ),
                  )
                ),
              ),
            ),
          ],
        )
      ),
      floatingActionButton: new FloatingActionButton(
        child: new Icon(Icons.add),
        onPressed: () {
          product.code = widget.code;
          state.addProduct(context, product);
          Navigator.pop(context, product);
        },
      ),
    );
  }
}
