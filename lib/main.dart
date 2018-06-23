import 'dart:typed_data';

import 'package:barcode_scan/barcode_scan.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventorio/model.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:loader_search_bar/loader_search_bar.dart';
import 'package:date_utils/date_utils.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  AppModel appModel;

  @override
  void initState() {
    appModel = AppModel();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return ScopedModel<AppModel>(
      model: appModel,
      child: MaterialApp(
        title: 'Inventorio',
        home: ListingsPage(),
      )
    );
  }
}

class ListingsPage extends StatelessWidget {

  void _addItem(BuildContext context) async {
    AppModel model = ModelFinder<AppModel>().of(context);
    if (!model.isSignedIn) { model.signIn(); return; }

    print('Scanning new item...');
    String code = await BarcodeScanner.scan();
    bool isProductIdentified = await model.isProductIdentified(code);

    Product product = isProductIdentified
      ? model.getAssociatedProduct(code)
      : await Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(Product(code: code)),),);

    print('Product $product');
    if (product == null) return;

    if (!isProductIdentified) {
      print('Attempting to add new product');
      model.addProduct(product);
    }

    print('Attempting to add new item');
    DateTime expiry =  await Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryAddPage(product),),);
    if (expiry == null) return;

    InventoryItem item = AppModelUtils.buildInventoryItem(code, expiry);
    if (item != null) model.addItem(item);
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 0.8,),
      child: Scaffold(
        appBar: SearchBar(
          defaultAppBar: AppBar(
            title: ScopedModelDescendant<AppModel>(
              builder: (context, child, model) => Text(model.currentInventory?.name ?? 'Inventory', style: TextStyle(fontFamily: 'Montserrat'),),
            ),
          ),
          searchHint: 'Filter',
          onActivatedChanged: (active) { if (!active) ModelFinder<AppModel>().of(context).filter = null; },
          onQueryChanged: (query) { ModelFinder<AppModel>().of(context).filter = query; },
        ),
        body:
          ScopedModelDescendant<AppModel>(
            builder: (context, child, model) => ListView.builder(
              cacheExtent: 1000.0,
              itemCount: model.inventoryItems.length,
              itemBuilder: (context, index) => InventoryItemTile(context, index),
            ),
          ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.extended(
          icon: Icon(Icons.add_a_photo),
          label: Text('Scan Barcode', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0)),
          backgroundColor: Theme.of(context).primaryColor,
          onPressed: () { _addItem(context); },
        ),
        drawer: Drawer(
          child: ScopedModelDescendant<AppModel>(
            builder: (context, child, model) => ListView(
              padding: EdgeInsets.zero,
              children: _buildDrawerItems(context, model),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDrawerItems(BuildContext context, AppModel model) {
    List<Widget> widgets = [
      DrawerHeader(
        decoration: BoxDecoration(color: Theme.of(context).primaryColor),
        child: ListTile(
          title: Text(model.currentInventory?.name ?? '', style: TextStyle(fontFamily: 'Montserrat', fontSize: 25.0, color: Colors.white, fontWeight: FontWeight.bold),),
          subtitle: Text(model.currentInventory?.uuid ?? '', style: TextStyle(fontFamily: 'Raleway', fontSize: 15.0, color: Colors.white),),
        ),
      ),
      ListTile(
        title: Text('Login with Google', style: TextStyle(fontFamily: 'Montserrat', fontSize: 20.0, fontWeight: FontWeight.bold),),
        subtitle: !model.isSignedIn? null: Text('Currently logged in as ' + model.userDisplayName, style: TextStyle(fontFamily: 'Raleway', fontSize: 16.0),),
        onTap: () {
          Navigator.of(context).pop(); model.signIn();
          if (model.isSignedIn) {
            model.sureDialog(context, 'Login with another account?', 'Sign-out', 'Cancel').then((sure) {
              if (sure) model.signOut();
            });
          } else {
            model.signIn();
          }
        },
      ),
      ListTile(
        enabled: model.isSignedIn,
        dense: true,
        title: Text('Create New Inventory', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0,),),
        onTap: () async {
          Navigator.of(context).pop();
          InventoryDetails inventory = await Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(null)));
          if (inventory != null) model.addInventory(inventory);
        },
      ),
      ListTile(
        enabled: model.isSignedIn,
        dense: true,
        title: Text('Scan Existing Inventory Code', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0),),
        onTap: () {
          Navigator.of(context).pop();
          model.scanInventory();
        },
      ),
      ListTile(
        enabled: model.isSignedIn,
        dense: true,
        title: Text('Edit/Share Inventory', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0),),
        onTap: () async {
          Navigator.of(context).pop();
          InventoryDetails details = model.currentInventory;
          InventoryDetails edited = await Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(details),));
          if (edited != null) model.addInventory(edited);
        },
      ),
      Divider(),
    ];

    model.userAccount?.knownInventories?.forEach((inventoryId) {
      widgets.add(
        ListTile(
          dense: true,
          title: Text(model.inventoryDetails[inventoryId].toString(), style: TextStyle(fontFamily: 'Raleway', fontSize: 18.0,), softWrap: false,),
          selected: (inventoryId == model.currentInventory.uuid),
          onTap: () {
            model.changeCurrentInventory(inventoryId);
            Navigator.of(context).pop();
          },
        )
      );
    });

    return widgets;
  }
}

class InventoryItemTile extends StatelessWidget {
  InventoryItemTile(this.context, this.index);
  final BuildContext context;
  final int index;

  Color _expiryColorScale(int days) {
    if (days < 30) return Colors.redAccent;
    else if (days < 90) return Colors.yellowAccent;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    AppModel model = ModelFinder<AppModel>().of(context);
    InventoryItem item = model.inventoryItems[index];
    Product product = model.getAssociatedProduct(item.code);
    return Dismissible(
      child: Container(
        height: 80.0,
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 1,
              child: CachedNetworkImage(
                imageUrl: product?.imageUrl ?? '',
                width: 78.0, height: 78.0, fit: BoxFit.cover,
                fadeOutDuration: Duration(milliseconds: 100),
                placeholder: Icon(Icons.camera_alt, color: Colors.grey.withOpacity(.30),),
                errorWidget: Icon(Icons.camera_alt, color: Colors.grey.withOpacity(.30),),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  product?.brand == null?   Container(): Text(product.brand,   style: TextStyle(fontFamily: 'Raleway',    fontSize: 17.0), textAlign: TextAlign.center,),
                  product?.name == null?    Container(): Text(product.name,    style: TextStyle(fontFamily: 'Montserrat', fontSize: 19.0), textAlign: TextAlign.center,),
                  product?.variant == null? Container(): Text(product.variant, style: TextStyle(fontFamily: 'Raleway',    fontSize: 17.0), textAlign: TextAlign.center,),
                ],
              ),
            ),
            Expanded(flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(item.year, style: TextStyle(fontFamily: 'Raleway', fontSize: 15.0, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                  Text('${item.month} ${item.day}', style: TextStyle(fontFamily: 'Raleway', fontSize: 18.0, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                ],
              )
            ),
            Container(
              width: 5.0, height: 80.0,
              color: _expiryColorScale(item.daysFromToday),
            ),
          ],
        )
      ),
      key: ObjectKey(item.uuid),
      background: Container(
        color: Colors.blueAccent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.delete, color: Colors.white),
            Text('Remove', style: TextStyle(fontFamily: 'Montserrat', color: Colors.white, fontWeight: FontWeight.bold),),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.lightBlueAccent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text('Edit Product', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),),
            Icon(Icons.edit),
          ],
        ),
      ),
      onDismissed: (direction) {
        AppModel model = ModelFinder<AppModel>().of(context);
        model.removeItem(item.uuid);

        if (direction == DismissDirection.startToEnd) {
          Scaffold.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed item ${product?.name}'),
              action: SnackBarAction(
                label: "UNDO",
                onPressed: () {
                  item.uuid = AppModelUtils.generateUuid();
                  model.addItem(item);
                },
              )
            )
          );
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(product),))
            .then((editedProduct) {
              if (editedProduct != null) model.addProduct(editedProduct);
              item.uuid = AppModelUtils.generateUuid();
              model.addItem(item);
          });
        }
      },
    );
  }
}

class InventoryAddPage extends StatefulWidget {
  final Product product;
  InventoryAddPage(this.product);
  @override _InventoryAddPageState createState() => _InventoryAddPageState();
}

class _InventoryAddPageState extends State<InventoryAddPage> {

  List<String> monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October','November','December',];
  FixedExtentScrollController yearController, monthController, dayController;
  int yearIndex, monthIndex, dayIndex;
  DateTime selectedYearMonth;
  DateTime selectedDate;
  DateTime now = DateTime.now();
  Product staging;

  @override
  void initState() {
    super.initState();
    yearController = FixedExtentScrollController();
    monthController = FixedExtentScrollController(initialItem: now.month - 1);
    dayController = FixedExtentScrollController(initialItem: now.day - 1);
    selectedYearMonth = DateTime(now.year, now.month);
    yearIndex = now.year;
    monthIndex = now.month;
    dayIndex = now.day;
    staging = widget.product;
  }

  Widget _createPicker(BuildContext context, {
    @required List<Widget> children,
    @required Function(int) onChange,
    @required FixedExtentScrollController scrollController}
  ) {
    return Expanded(
      flex: 1,
      child: Container(
        height: 200.0,
        child: CupertinoPicker(
          scrollController: scrollController,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          itemExtent: 40.0,
          onSelectedItemChanged: onChange,
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 0.8,),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.product.code ?? '', style: TextStyle(fontFamily: 'Montserrat'),),),
        body: ListView(
          children: <Widget>[
            Container(
              height: 180.0,
              child: ScopedModelDescendant<AppModel>(
                builder: (context, child, model) => Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CachedNetworkImage(
                          imageUrl: staging.imageUrl ?? '', width: 150.0, height: 150.0, fit: BoxFit.cover,
                          placeholder: Icon(Icons.camera_alt, color: Colors.grey.withOpacity(0.3), size: 150.0,),
                          errorWidget: Icon(Icons.camera_alt, color: Colors.grey.withOpacity(0.3), size: 150.0,),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(staging.brand ?? '',   style: TextStyle(fontFamily: 'Raleway',    fontSize: 20.0), textAlign: TextAlign.left,),
                          Text(staging.name ?? '',    style: TextStyle(fontFamily: 'Montserrat', fontSize: 25.0), textAlign: TextAlign.left,),
                          Text(staging.variant ?? '', style: TextStyle(fontFamily: 'Raleway',    fontSize: 20.0), textAlign: TextAlign.left,),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            Divider(),
            Row(
              children: <Widget>[
                _createPicker(
                  context,
                  onChange: (index) { yearIndex = index + now.year; selectedYearMonth = DateTime(yearIndex, monthIndex); },
                  scrollController: yearController,
                  children: List<Widget>.generate(10, (int index) {
                    return Center(
                      child: Text('${index + 2018}', style: TextStyle(fontFamily: 'Montserrat', fontSize: 30.0))
                    );
                  })
                ),
                _createPicker(
                  context,
                  onChange: (index) { monthIndex = index + 1; selectedYearMonth = DateTime(now.year, monthIndex); },
                  scrollController: monthController,
                  children: List<Widget>.generate(12, (int index) {
                    return Center(
                      child: Text(monthNames[index], style: TextStyle(fontFamily: 'Montserrat', fontSize: 30.0))
                    );
                  })
                ),
                _createPicker(
                  context,
                  onChange: (index) { dayIndex = index + 1; },
                  scrollController: dayController,
                  children: List<Widget>.generate(Utils.lastDayOfMonth(selectedYearMonth).day, (int index) {
                    return Center(
                      child: Text('${index + 1}', style: TextStyle(fontFamily: 'Montserrat', fontSize: 30.0))
                    );
                  })
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.input),
          onPressed: () => Navigator.pop(context, DateTime(yearIndex, monthIndex, dayIndex)),
        ),
      ),
    );
  }
}

class ProductPage extends StatefulWidget {
  ProductPage(this.product);
  final Product product;
  @override _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  Product staging;
  TextEditingController _brand, _name, _variant;
  Uint8List stagingImage;

  @override
  void initState() {
    super.initState();
    staging = widget.product;
    stagingImage = kTransparentImage;
    _brand = TextEditingController(text: staging.brand);
    _name = TextEditingController(text: staging.name);
    _variant = TextEditingController(text: staging.variant);

    ModelFinder<AppModel>().of(context).imageData = null;
  }

  @override
  Widget build(BuildContext context) {
    AppModel model = ModelFinder<AppModel>().of(context);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 0.8),
      child: Scaffold(
        appBar: AppBar(title: Text(staging.code, style: TextStyle(fontFamily: 'Montserrat'),),),
        body: ListView(
          children: <Widget>[
            ListTile(
              title: TextField(
                controller: _brand,
                onChanged: (s) => staging.brand = AppModelUtils.capitalizeWords(s),
                decoration: InputDecoration(hintText: 'Brand'),
                style: TextStyle(fontFamily: 'Montserrat', color: Colors.black, fontSize: 18.0),
              ),
              trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () { _brand.clear(); staging.brand = null; }),
            ),
            ListTile(
              title: TextField(
                controller: _name,
                onChanged: (s) => staging.name = AppModelUtils.capitalizeWords(s),
                decoration: InputDecoration(hintText: 'Product Name'),
                style: TextStyle(fontFamily: 'Montserrat', color: Colors.black, fontSize: 18.0),
              ),
              trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () { _name.clear(); staging.name = null; }),
            ),
            ListTile(
              title: TextField(
                controller: _variant,
                onChanged: (s) => staging.variant = AppModelUtils.capitalizeWords(s),
                decoration: InputDecoration(hintText: 'Variant'),
                style: TextStyle(fontFamily: 'Montserrat', color: Colors.black, fontSize: 18.0),
              ),
              trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () { _variant.clear(); staging.variant = null; }),
            ),
            Divider(),
            FlatButton(
              onPressed: () {
                ImagePicker.pickImage(source: ImageSource.camera).then((file) {
                  setState(() {
                    stagingImage = file.readAsBytesSync();
                    model.imageData = stagingImage;
                    file.deleteSync();
                  });
                });
              },
              child: Stack(
                children: <Widget>[
                  CachedNetworkImage(
                    imageUrl: staging.imageUrl ?? '', width: 250.0, height: 250.0, fit: BoxFit.cover,
                    placeholder: Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: 180.0,)),
                    errorWidget: Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: 180.0)),
                  ),
                  Center(child: Image.memory(stagingImage, width: 250.0, height: 250.0, fit: BoxFit.cover,)),
                ]
              ),
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.input),
          onPressed: () => Navigator.pop(context, staging),
        ),
      )
    );
  }
}

class InventoryDetailsPage extends StatefulWidget {
  InventoryDetailsPage(this.inventoryDetails);
  final InventoryDetails inventoryDetails;
  @override _InventoryDetailsState createState() => _InventoryDetailsState();
}

class _InventoryDetailsState extends State<InventoryDetailsPage> {
  InventoryDetails staging;
  TextEditingController _name;

  @override
  void initState() {
    super.initState();
    staging = widget.inventoryDetails == null
      ? new InventoryDetails(uuid: AppModelUtils.generateUuid())
      : widget.inventoryDetails;
    _name = TextEditingController(text: staging.name);
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 0.8),
      child: Scaffold(
        appBar: AppBar(title: Text(staging.uuid, style: TextStyle(fontFamily: 'Montserrat', fontSize: 15.0),),),
        body: ListView(
          children: <Widget>[
            ListTile(
              title: TextField(
                controller: _name,
                onChanged: (s) => staging.name = AppModelUtils.capitalizeWords(s),
                decoration: InputDecoration(hintText: 'New Inventory Name'),
                style: TextStyle(fontFamily: 'Montserrat', color: Colors.black, fontSize: 18.0),
              ),
              trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () { _name.clear(); staging.name = null; }),
            ),
            Divider(),
            ListTile(title: Text('Share this inventory by scanning the image below.', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0),),),
            Center(
              child: QrImage(
                data: staging.uuid,
                size: 250.0,
              ),
            ),
            widget.inventoryDetails == null
            ? Container(width: 0.0, height: 0.0,)
            : ListTile(
              title: RaisedButton(
                child: Text('Unsubscribe to inventory', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0),),
                onPressed: () async {
                  AppModel model = ModelFinder<AppModel>().of(context);
                  if (await model.sureDialog(context, 'Are you sure?', 'Unsubscribe', 'Cancel')) {
                    model.unsubscribeInventory(staging.uuid);
                    Navigator.pop(context, null);
                  }
                }
              ),
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.input),
          onPressed: () => Navigator.pop(context, staging),
        ),
      ),
    );
  }
}