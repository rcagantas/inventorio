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
        theme: ThemeData.light().copyWith(
          primaryColor: Colors.blue.shade700,
          primaryTextTheme: TextTheme(
            title: TextStyle(fontFamily: 'Montserrat', fontSize: 15.0, color: Colors.white),
            display1: TextStyle(fontFamily: 'Montserrat', fontSize: 15.0, color: Colors.black),
            display2: TextStyle(fontFamily: 'Raleway', fontSize: 13.0, color: Colors.black),
          ),
        ),
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

    print('Attempting to add new item');
    Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryAddPage(product, newItem: !isProductIdentified),),);
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0,),
      child: Scaffold(
        appBar: SearchBar(
          defaultAppBar: AppBar(
            title: ScopedModelDescendant<AppModel>(
              builder: (context, child, model) => Text(model.currentInventory?.name ?? 'Inventory', style: Theme.of(context).primaryTextTheme.title),
            ),
          ),
          searchHint: 'Filter',
          onActivatedChanged: (active) { if (!active) ModelFinder<AppModel>().of(context).filter = null; },
          onQueryChanged: (query) { ModelFinder<AppModel>().of(context).filter = query; },
        ),
        body:
          ScopedModelDescendant<AppModel>(
            builder: (context, child, model) => ListView.builder(
              itemExtent: 80.0,
              itemCount: model.inventoryItems.length + 1,
              itemBuilder: (context, index) => index == model.inventoryItems.length
                ? SizedBox(height: 80.0) // add an item for padding against floating button
                : InventoryItemTile(context, index),
            ),
          ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.extended(
          icon: Icon(Icons.add_a_photo),
          label: Text('Scan Barcode', style: Theme.of(context).primaryTextTheme.title),
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
          title: Text(model.currentInventory?.name ?? '', style: Theme.of(context).primaryTextTheme.title.copyWith(fontSize: 20.0, fontWeight: FontWeight.bold),),
          subtitle: Text('${model.inventoryItems.length} items', style: Theme.of(context).primaryTextTheme.display2.copyWith(color: Colors.white),),
        ),
      ),
      ListTile(
        title: Text('Login with Google', style: Theme.of(context).primaryTextTheme.display1.copyWith(fontWeight: FontWeight.bold),),
        subtitle: !model.isSignedIn? null: Text('Currently logged in as ' + model.userDisplayName, style: Theme.of(context).primaryTextTheme.display2,),
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
        title: Text('Create New Inventory', style: Theme.of(context).primaryTextTheme.display1,),
        onTap: () async {
          Navigator.of(context).pop();
          InventoryDetails inventory = await Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(null)));
          if (inventory != null) model.addInventory(inventory);
        },
      ),
      ListTile(
        enabled: model.isSignedIn,
        dense: true,
        title: Text('Scan Existing Inventory Code', style: Theme.of(context).primaryTextTheme.display1,),
        onTap: () {
          Navigator.of(context).pop();
          model.scanInventory();
        },
      ),
      ListTile(
        enabled: model.isSignedIn,
        dense: true,
        title: Text('Edit/Share Inventory', style: Theme.of(context).primaryTextTheme.display1,),
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
          title: Text(
            model.inventoryDetails[inventoryId].toString(),
            style: Theme.of(context).primaryTextTheme.display2
              .copyWith(fontWeight: inventoryId == model.currentInventory.uuid? FontWeight.bold : FontWeight.normal),
            softWrap: false,),
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
            SizedBox(
              width: 78.0, height: 78.0,
              child: product?.imageUrl == null
              ? Icon(Icons.camera_alt, color: Colors.grey.shade400,)
              : CachedNetworkImage(
                imageUrl: product?.imageUrl ?? '', fit: BoxFit.cover,
                placeholder: Center(child: Icon(Icons.camera_alt, color: Colors.grey)),
                errorWidget: Center(child: Icon(Icons.error_outline, color: Colors.grey)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  product?.brand == null?   Container(): Text(product.brand,   style: Theme.of(context).primaryTextTheme.display2, textAlign: TextAlign.center,),
                  product?.name == null?    Container(): Text(product.name,    style: Theme.of(context).primaryTextTheme.display1, textAlign: TextAlign.center,),
                  product?.variant == null? Container(): Text(product.variant, style: Theme.of(context).primaryTextTheme.display2, textAlign: TextAlign.center,),
                ],
              ),
            ),
            Expanded(flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(item.year, style: Theme.of(context).primaryTextTheme.display2.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                  Text('${item.month} ${item.day}', style: Theme.of(context).primaryTextTheme.display2.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
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
            Text('Remove', style: Theme.of(context).primaryTextTheme.display1.copyWith(fontSize: 12.0, color: Colors.white, fontWeight: FontWeight.bold),),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.lightBlueAccent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text('Edit Product', style: Theme.of(context).primaryTextTheme.display1.copyWith(fontSize: 12.0, color: Colors.white, fontWeight: FontWeight.bold),),
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
                  model.addItem(item); // undo remove
                },
              )
            )
          );
        } else {
          item.uuid = AppModelUtils.generateUuid();
          model.addItem(item); // edit product
          Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(product),));
        }
      },
    );
  }
}

class InventoryAddPage extends StatefulWidget {
  final Product product;
  final bool newItem;
  InventoryAddPage(this.product, {this.newItem = false});
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
      data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0,),
      child: Scaffold(
        appBar: AppBar(title: Text(widget.product.code ?? '', style: Theme.of(context).primaryTextTheme.title,),),
        body: ListView(
          children: <Widget>[
            Container(
              height: 180.0,
              child: ScopedModelDescendant<AppModel>(
                builder: (context, child, model) => FlatButton(
                  onPressed: () async {
                    Product temp = await Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(staging)));
                    if (temp != null) staging = temp;
                  },
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          width: 150.0, height: 150.0,
                          child: staging?.imageUrl == null
                          ? Icon(Icons.camera_alt, color: Colors.grey.shade400, size: 100.0,)
                          : CachedNetworkImage(
                            imageUrl: staging?.imageUrl ?? '', fit: BoxFit.cover,
                            placeholder: Center(child: Icon(Icons.camera_alt, color: Colors.grey)),
                            errorWidget: Center(child: Icon(Icons.error_outline, color: Colors.grey)),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(staging.brand ?? '',   style: Theme.of(context).primaryTextTheme.display2.copyWith(fontSize: 16.0), textAlign: TextAlign.center,),
                            Text(staging.name ?? '',    style: Theme.of(context).primaryTextTheme.display1.copyWith(fontSize: 18.0), textAlign: TextAlign.center,),
                            Text(staging.variant ?? '', style: Theme.of(context).primaryTextTheme.display2.copyWith(fontSize: 16.0), textAlign: TextAlign.center,),
                          ],
                        ),
                      )
                    ],
                  ),
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
                      child: Text('${index + 2018}', style: Theme.of(context).primaryTextTheme.display1.copyWith(fontSize: 18.0))
                    );
                  })
                ),
                _createPicker(
                  context,
                  onChange: (index) {
                    monthIndex = index + 1;
                    setState(() {
                      selectedYearMonth = DateTime(now.year, monthIndex);
                    });
                  },
                  scrollController: monthController,
                  children: List<Widget>.generate(12, (int index) {
                    return Center(
                      child: Text(monthNames[index], style: Theme.of(context).primaryTextTheme.display1.copyWith(fontSize: 18.0))
                    );
                  })
                ),
                _createPicker(
                  context,
                  onChange: (index) { dayIndex = index + 1; },
                  scrollController: dayController,
                  children: List<Widget>.generate(Utils.lastDayOfMonth(selectedYearMonth).day, (int index) {
                    return Center(
                      child: Text('${index + 1}', style: Theme.of(context).primaryTextTheme.display1.copyWith(fontSize: 18.0))
                    );
                  })
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.input),
          onPressed: () {
            DateTime expiryDate = DateTime(yearIndex, monthIndex, dayIndex);
            InventoryItem item = AppModelUtils.buildInventoryItem(staging.code, expiryDate);
            if (item != null) ModelFinder<AppModel>().of(context).addItem(item);
            Navigator.pop(context, expiryDate);
          },
          backgroundColor: Theme.of(context).primaryColor,
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
  }

  @override
  Widget build(BuildContext context) {
    AppModel model = ModelFinder<AppModel>().of(context);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
      child: Scaffold(
        appBar: AppBar(title: Text(staging.code, style: Theme.of(context).primaryTextTheme.title,),),
        body: ListView(
          children: <Widget>[
            ListTile(
              title: TextField(
                controller: _brand,
                onChanged: (s) => staging.brand = AppModelUtils.capitalizeWords(s),
                decoration: InputDecoration(hintText: 'Brand'),
                style: Theme.of(context).primaryTextTheme.display1,
              ),
              trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () { _brand.clear(); staging.brand = null; }),
            ),
            ListTile(
              title: TextField(
                controller: _name,
                onChanged: (s) => staging.name = AppModelUtils.capitalizeWords(s),
                decoration: InputDecoration(hintText: 'Product Name'),
                style: Theme.of(context).primaryTextTheme.display1,
              ),
              trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () { _name.clear(); staging.name = null; }),
            ),
            ListTile(
              title: TextField(
                controller: _variant,
                onChanged: (s) => staging.variant = AppModelUtils.capitalizeWords(s),
                decoration: InputDecoration(hintText: 'Variant'),
                style: Theme.of(context).primaryTextTheme.display1,
              ),
              trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () { _variant.clear(); staging.variant = null; }),
            ),
            Divider(),
            FlatButton(
              onPressed: () {
                ImagePicker.pickImage(source: ImageSource.camera).then((file) {
                  AppModelUtils.resizeImage(file)
                    .then((data) { setState(() { stagingImage = data; }); })
                    .whenComplete(() { file.delete(); });
                });
              },
              child: Stack(
                children: <Widget>[
                  Center(
                    child: SizedBox(
                      width: 250.0, height: 250.0,
                      child: staging?.imageUrl == null
                      ? Icon(Icons.camera_alt, color: Colors.grey.shade400, size: 200.0,)
                      : CachedNetworkImage(
                        imageUrl: staging?.imageUrl ?? '', fit: BoxFit.cover,
                        placeholder: Center(child: Icon(Icons.camera_alt, color: Colors.grey)),
                        errorWidget: Center(child: Icon(Icons.error_outline, color: Colors.grey)),
                      ),
                    ),
                  ),
                  Center(child: Image.memory(stagingImage, width: 250.0, height: 250.0, fit: BoxFit.cover,)),
                ]
              ),
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.input),
          onPressed: () {
            model.addProduct(staging); // add product
            if (stagingImage != kTransparentImage)
              model.addProductImage(staging, stagingImage); // update with image;
            Navigator.pop(context, staging);
          },
          backgroundColor: Theme.of(context).primaryColor,
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
      data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
      child: Scaffold(
        appBar: AppBar(title: Text(staging.uuid, style: Theme.of(context).primaryTextTheme.title,),),
        body: ListView(
          children: <Widget>[
            ListTile(
              title: TextField(
                controller: _name,
                onChanged: (s) => staging.name = AppModelUtils.capitalizeWords(s),
                decoration: InputDecoration(hintText: 'New Inventory Name'),
                style: Theme.of(context).primaryTextTheme.display1,
              ),
              trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () { _name.clear(); staging.name = null; }),
            ),
            Divider(),
            ListTile(title: Text('Share this inventory by scanning the image below.', style: Theme.of(context).primaryTextTheme.display1,),),
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
                child: Text('Unsubscribe to inventory', style: Theme.of(context).primaryTextTheme.display1,),
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