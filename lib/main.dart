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
import 'package:flutter_slidable/flutter_slidable.dart';

void main() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
    .then((_) => runApp(MyApp()));
}

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
    return ScopedModel<AppModel>(
      model: appModel,
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          selectedRowColor: Colors.lightBlueAccent,
          primaryColor: Colors.blue.shade700,
          primaryTextTheme: TextTheme(
            title: TextStyle(fontFamily: 'Montserrat', fontSize: 16.0, color: Colors.white),
            display1: TextStyle(fontFamily: 'Montserrat', fontSize: 16.0, color: Colors.black),
            display2: TextStyle(fontFamily: 'Raleway', fontSize: 14.0, color: Colors.black),
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
    if (code.contains('/')) {
      Scaffold.of(context).showSnackBar(
        SnackBar(
          content: Text("Invalid code: $code"), duration: Duration(seconds: 5),
          action: SnackBarAction(label: "COPY", onPressed: () { Clipboard.setData(ClipboardData(text: code));},)
        )
      );
      return;
    }

    print('Attempting to add new item');
    Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryAddPage(code)));
  }

  Widget _buildWelcome(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.add_a_photo, color: Colors.grey.shade400, size: 150.0,),
          ListTile(title: Text('Welcome to Inventorio', style: Theme.of(context).primaryTextTheme.display1.copyWith(fontSize: 20.0), textAlign: TextAlign.center,)),
          ListTile(title: Text('Scanned items and expiration dates will appear here. ', style: Theme.of(context).primaryTextTheme.display1.copyWith(color: Colors.grey), textAlign: TextAlign.center,)),
          ListTile(title: Text('Scan new items by clicking the button below.', style: Theme.of(context).primaryTextTheme.display1.copyWith(color: Colors.grey), textAlign: TextAlign.center,)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          builder: (context, child, model) {
            return model.inventoryItems.length > 0
            ? ListView.builder(
              itemCount: model.inventoryItems.length,
              itemBuilder: (context, index) => InventoryItemTile(context, index)
            )
            : _buildWelcome(context);
          },
        ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Builder(
        builder: (BuildContext context) => FloatingActionButton.extended(
          icon: Icon(Icons.add_a_photo),
          label: Text('Scan Barcode', style: Theme.of(context).primaryTextTheme.title),
          backgroundColor: Theme.of(context).primaryColor,
          onPressed: () { _addItem(context); },
        ),
      ),
      drawer: Drawer(
        child: ScopedModelDescendant<AppModel>(
          builder: (context, child, model) => ListView(
            padding: EdgeInsets.zero,
            children: _buildDrawerItems(context, model),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDrawerItems(BuildContext context, AppModel model) {
    List<Widget> widgets = [
      UserAccountsDrawerHeader(
        accountName: Text(model.currentInventory?.name ?? '', style: Theme.of(context).primaryTextTheme.title.copyWith(fontSize: 20.0, fontWeight: FontWeight.bold),),
        accountEmail: Text('${model.inventoryItems?.length ?? '?'} items', style: Theme.of(context).primaryTextTheme.display2.copyWith(color: Colors.white),),
        currentAccountPicture: CircleAvatar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          backgroundImage: AssetImage('resources/icons/icon.png'),
        ),
      ),
      ListTile(
        title: Text(model.isSignedIn? 'Log out': 'Login with Google', style: Theme.of(context).primaryTextTheme.display1.copyWith(fontWeight: FontWeight.bold),),
        subtitle: !model.isSignedIn? null: Text('Currently logged in as ${model.userDisplayName ?? '_'}', style: Theme.of(context).primaryTextTheme.display2,),
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
      ExpansionTile(
        title: Text('Inventory Management', style: Theme.of(context).primaryTextTheme.display1),
        children: <Widget>[
          ListTile(
            enabled: model.isSignedIn,
            dense: true,
            title: Text('Create New Inventory', style: Theme.of(context).primaryTextTheme.display1,),
            onTap: () async {
              InventoryDetails inventory = await Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(null)));
              if (inventory != null) model.addInventory(inventory);
            },
          ),
          ListTile(
            enabled: model.isSignedIn,
            dense: true,
            title: Text('Scan Existing Inventory Code', style: Theme.of(context).primaryTextTheme.display1,),
            onTap: () async {
              String code = await BarcodeScanner.scan();
              bool valid = await model.scanInventory(code);

              if (!valid) { model.sureDialog(context, 'Invalid code $code. ', null, 'OK'); }
            },
          ),
          ListTile(
            enabled: model.isSignedIn,
            dense: true,
            title: Text('Edit/Share Inventory', style: Theme.of(context).primaryTextTheme.display1,),
            onTap: () async {
              InventoryDetails details = model.currentInventory;
              InventoryDetails edited = await Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(details),));
              if (edited != null) model.addInventory(edited);
            },
          ),
          ListTile(
            dense: true,
            title: Text('Logs', style: Theme.of(context).primaryTextTheme.display1,),
            onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => LogPage())); }
          ),
        ],
      ),
      Divider(),
    ];

    model.userAccount?.knownInventories?.forEach((inventoryId) {
      if (model.currentInventory == null) return;
      widgets.add(
        ListTile(
          selected: inventoryId == model.currentInventory.uuid,
          isThreeLine: false,
          dense: true,
          title: Text(
            model.inventoryDetails[inventoryId]?.name ?? 'Inventory',
            style: Theme.of(context).primaryTextTheme.display1.copyWith(fontWeight: inventoryId == model.currentInventory.uuid? FontWeight.bold : FontWeight.normal),
            softWrap: false,
          ),
          subtitle: Text(
            model.inventoryItemCount.containsKey(inventoryId)? '${model.inventoryItemCount[inventoryId]} items': '',
            style: Theme.of(context).primaryTextTheme.display2.copyWith(color: Colors.grey),
            softWrap: false,
          ),
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

  bool isNullOrEmpty(String test) {
    return test == null || test == '';
  }

  @override
  Widget build(BuildContext context) {
    AppModel model = ModelFinder<AppModel>().of(context);
    InventoryItem item = model.inventoryItems[index];
    Product product = model.getAssociatedProduct(item.code);
    double textScaleFactor = MediaQuery.of(context).textScaleFactor;
    double adjustedHeight = 100.0 * textScaleFactor;

    return Slidable(
      delegate: SlidableDrawerDelegate(),
      actionExtentRatio: 0.25,
      child: Container(
        height: adjustedHeight,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 78.0, height: adjustedHeight - 2.0,
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
                  isNullOrEmpty(product?.brand)?   Container(): Text(product.brand,   style: Theme.of(context).primaryTextTheme.display2, textAlign: TextAlign.center,),
                  isNullOrEmpty(product?.name)?    Container(): Text(product.name,    style: Theme.of(context).primaryTextTheme.display1, textAlign: TextAlign.center,),
                  isNullOrEmpty(product?.variant)? Container(): Text(product.variant, style: Theme.of(context).primaryTextTheme.display2, textAlign: TextAlign.center,),
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
              width: 5.0, height: adjustedHeight,
              color: _expiryColorScale(item.daysFromToday),
            ),
          ],
        )
      ),
      key: ObjectKey(item.uuid),
      secondaryActions: <Widget>[
        IconSlideAction(
          caption: 'Edit Product',
          color: Colors.lightBlueAccent,
          icon: Icons.edit,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(product),));
          }
        ),
        IconSlideAction(
          caption: 'Delete',
          color: Colors.red,
          icon: Icons.delete,
          onTap: () {
            AppModel model = ModelFinder<AppModel>().of(context);
            model.removeItem(item.uuid);
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
          },
        ),
      ],
    );
  }
}

class InventoryAddPage extends StatefulWidget {
  final String code;
  InventoryAddPage(this.code);
  @override _InventoryAddPageState createState() => _InventoryAddPageState();
}

class _InventoryAddPageState extends State<InventoryAddPage> {

  List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct','Nov','Dec',];
  FixedExtentScrollController yearController, monthController, dayController;
  int yearIndex, monthIndex, dayIndex;
  DateTime selectedYearMonth;
  DateTime selectedDate;
  DateTime now = DateTime.now();
  Product staging;
  bool isLoading = true;
  bool known = false;

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

    AppModel model = ModelFinder<AppModel>().of(context);
    model.isProductIdentified(widget.code).then((known) {
      setState(() {
        this.known = known;
        this.staging = known? model.getAssociatedProduct(widget.code) : null;
        this.isLoading = false;
      });
    });
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
    TextStyle pickerStyle = Theme.of(context).primaryTextTheme.display1.copyWith(fontSize: 25.0);
    return Scaffold(
      appBar: AppBar(title: Text(widget.code ?? '', style: Theme.of(context).primaryTextTheme.title,),),
      body: ListView(
        children: <Widget>[
          Container(
            height: 160.0,
            child: ScopedModelDescendant<AppModel>(
              builder: (context, child, model) => FlatButton(
                onPressed: () async {
                  Product temp = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProductPage(staging != null? staging: Product(code: widget.code)))
                  ); // edit from item
                  if (temp != null) setState(() { staging = temp; });
                },
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        width: 130.0, height: 130.0,
                        child: staging?.imageUrl == null
                        ? Icon(Icons.camera_alt, color: Colors.grey.shade400, size: 80.0,)
                        : CachedNetworkImage(
                          imageUrl: staging?.imageUrl ?? '', fit: BoxFit.cover,
                          placeholder: Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: 80.0,)),
                          errorWidget: Center(child: Icon(Icons.error_outline, color: Colors.grey, size: 80.0,)),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: isLoading? Center(child: CircularProgressIndicator()) : Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(staging?.brand ?? '',            style: Theme.of(context).primaryTextTheme.display2.copyWith(fontSize: 16.0), textAlign: TextAlign.center,),
                            Text(staging?.name ?? 'Unknown Item', style: Theme.of(context).primaryTextTheme.display1.copyWith(fontSize: 18.0), textAlign: TextAlign.center,),
                            Text(staging?.variant ?? '',          style: Theme.of(context).primaryTextTheme.display2.copyWith(fontSize: 16.0), textAlign: TextAlign.center),
                          ],
                        ),
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
                  return Center(child: Text('${index + 2018}', style: pickerStyle));
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
                  return Center(child: Text(monthNames[index], style: pickerStyle));
                })
              ),
              _createPicker(
                context,
                onChange: (index) { dayIndex = index + 1; },
                scrollController: dayController,
                children: List<Widget>.generate(Utils.lastDayOfMonth(selectedYearMonth).day, (int index) {
                  return Center(child: Text('${index + 1}', style: pickerStyle));
                })
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.input),
        onPressed: isLoading? null: () async {
          staging = staging == null
            ? await Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(Product(code: widget.code))))
            : staging;

          if (staging == null) return;
          DateTime expiryDate = DateTime(yearIndex, monthIndex, dayIndex);
          InventoryItem item = AppModelUtils.buildInventoryItem(staging.code, expiryDate);
          if (item != null) ModelFinder<AppModel>().of(context).addItem(item);
          Navigator.pop(context, expiryDate);
        },
        backgroundColor: isLoading? Colors.grey: Theme.of(context).primaryColor,
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
  bool isResizing = false;

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

    return Scaffold(
      appBar: AppBar(title: Text(staging.code, style: Theme.of(context).primaryTextTheme.title,),),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: TextField(
              controller: _brand,
              decoration: InputDecoration(hintText: 'Brand'),
              style: Theme.of(context).primaryTextTheme.display1,
            ),
            trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () { _brand.clear(); staging.brand = null; }),
          ),
          ListTile(
            title: TextField(
              controller: _name,
              decoration: InputDecoration(hintText: 'Product Name'),
              style: Theme.of(context).primaryTextTheme.display1,
            ),
            trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () { _name.clear(); staging.name = null; }),
          ),
          ListTile(
            title: TextField(
              controller: _variant,
              decoration: InputDecoration(hintText: 'Variant/Flavor/Volume'),
              style: Theme.of(context).primaryTextTheme.display1,
            ),
            trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () { _variant.clear(); staging.variant = null; }),
          ),
          Divider(),
          FlatButton(
            onPressed: () {
              ImagePicker.pickImage(source: ImageSource.camera).then((file) {
                setState(() { isResizing = true; });
                AppModelUtils.resizeImage(file)
                  .then((data) {
                    setState(() { stagingImage = data; });
                  })
                  .whenComplete(() {
                    file.delete();
                    setState(() { isResizing = false; });
                  });
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
                      placeholder: Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: 200.0)),
                      errorWidget: Center(child: Icon(Icons.error_outline, color: Colors.grey, size: 200.0)),
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
          if (staging == null || isResizing) return;
          staging.brand = AppModelUtils.capitalizeWords(_brand.text);
          staging.name = AppModelUtils.capitalizeWords(_name.text);
          staging.variant = AppModelUtils.capitalizeWords(_variant.text);
          model.addProduct(staging); // add product
          if (stagingImage != kTransparentImage)
            model.addProductImage(staging, stagingImage); // update with image;
          Navigator.pop(context, staging);
        },
        backgroundColor: isResizing? Colors.grey: Theme.of(context).primaryColor,
      ),
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
      ? InventoryDetails(uuid: AppModelUtils.generateUuid())
      : widget.inventoryDetails;
    _name = TextEditingController(text: staging.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inventory Settings', style: Theme.of(context).primaryTextTheme.title,),),
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
          Text(staging.uuid, style: Theme.of(context).primaryTextTheme.display2, textAlign: TextAlign.center,),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.input),
        onPressed: () => Navigator.pop(context, staging),
      ),
    );
  }
}

class LogPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Logs', style: Theme.of(context).primaryTextTheme.title,),),
      body: ScopedModelDescendant<AppModel>(
        builder: (context, child, model) => ListView.builder(
          itemCount: model.logMessages.length,
          itemBuilder: (context, index) => Text(model.logMessages[index])
        ),
      ),
    );
  }
}