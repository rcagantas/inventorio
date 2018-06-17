import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventorio/model.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:loader_search_bar/loader_search_bar.dart';

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
              itemCount: model.inventoryItems.length,
              itemBuilder: (context, index) => InventoryItemTile(context, index),
            ),
          ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add_a_photo),
          backgroundColor: Theme.of(context).primaryColor,
          onPressed: () async {
            AppModel model = ModelFinder<AppModel>().of(context);
            InventoryItem item = await AppModelUtils.buildInventoryItem(context);
            if (item != null) {
              bool isProductIdentified = await model.isProductIdentified(item.code);

              if (!isProductIdentified) {
                Product product = await Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(Product(code: item.code)),),);
                if (product != null) {
                  model.addProduct(product);
                  model.addItem(item);
                }
              } else {
                model.addItem(item);
              }
            }
          },
        ),
        drawer: Drawer(
          child: ScopedModelDescendant<AppModel>(
            builder: (context, child, model) {
              int prepend = 5;
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: prepend + model.userAccount.knownInventories.length,
                itemBuilder: (context, index) {
                  switch(index) {
                    case 0:
                      return DrawerHeader(
                        decoration: BoxDecoration(color: Theme.of(context).primaryColor),
                        child: ListTile(
                          leading: CircleAvatar(backgroundImage: CachedNetworkImageProvider(model.userImageUrl),),
                          title: Text(model.userDisplayName, style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0, color: Colors.white),),
                        ),
                      );
                      break;
                    case 1:
                      return ListTile(
                        dense: true,
                        title: Text('Create New Inventory', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0),),
                        onTap: () async {
                          InventoryDetails inventory = await Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(null)));
                          if (inventory != null) model.addInventory(inventory);
                        },
                      );
                      break;
                    case 2:
                      return ListTile(

                        dense: true,
                        title: Text('Scan Existing Inventory Code', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0),),
                        onTap: () {
                          model.scanInventory();
                          Navigator.of(context).pop();
                        },
                      );
                      break;
                    case 3:
                      return ListTile(
                        dense: true,
                        title: Text('Edit/Share Inventory', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0),),
                        onTap: () async {
                          InventoryDetails details = model.currentInventory;
                          InventoryDetails edited = await Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryDetailsPage(details),));
                          if (edited != null) model.addInventory(edited);
                          Navigator.of(context).pop();
                        },
                      );
                      break;
                    case 4: return Divider(); break;
                    default:
                      return ListTile(
                        dense: true,
                        title: Text(model.inventoryDetails[model.userAccount.knownInventories[index-prepend]].toString(), style: TextStyle(fontFamily: 'Raleway', fontSize: 18.0,), softWrap: false,),
                        selected: (model.userAccount.knownInventories[index-prepend] == model.currentInventory.uuid),
                        onTap: () {
                          model.changeCurrentInventory(model.userAccount.knownInventories[index-prepend]);
                          Navigator.of(context).pop();
                        },
                      );
                      break;
                  }
                }
              );
            },
          ),
        ),
      ),
    );
  }
}

class InventoryItemTile extends StatelessWidget {
  InventoryItemTile(this.context, this.index);
  final BuildContext context;
  final int index;

  Color _expiryColorScale(DateTime expiryDate) {
    DateTime today = DateTime.now();
    Duration duration = expiryDate?.difference(today) ?? Duration(days: 0);
    if (duration.inDays < 30) return Colors.redAccent;
    else if (duration.inDays < 90) return Colors.yellowAccent;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    AppModel model = ModelFinder<AppModel>().of(context);
    InventoryItem item = model.inventoryItems[index];
    Product product = model.getAssociatedProduct(item.code);
    return Dismissible(
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 1,
            child: product?.imageUrl == null
              ? Image.memory(kTransparentImage)
              : CachedNetworkImage(imageUrl: product.imageUrl, width: 78.0, height: 78.0, fit: BoxFit.cover,),
          ),
          Expanded(
            flex: 3,
            child: Column(children: <Widget>[
                product?.brand == null?   Container(): Text(product.brand,   style: TextStyle(fontFamily: 'Raleway',    fontSize: 16.0), textAlign: TextAlign.center,),
                product?.name == null?    Container(): Text(product.name,    style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0), textAlign: TextAlign.center,),
                product?.variant == null? Container(): Text(product.variant, style: TextStyle(fontFamily: 'Raleway',    fontSize: 16.0), textAlign: TextAlign.center,),
              ],
            ),
          ),
          Expanded(flex: 1,
            child: Column(
              children: <Widget>[
                Text(item.year, style: TextStyle(fontFamily: 'Raleway', fontSize: 15.0, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                Text('${item.month} ${item.day}', style: TextStyle(fontFamily: 'Raleway', fontSize: 18.0, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
              ],
            )
          ),
          Container(
            width: 5.0, height: 80.0,
            color: _expiryColorScale(item.expiryDate),
          ),
        ],
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
            ListTile(
              title: FlatButton(
                onPressed: () {
                  ImagePicker.pickImage(source: ImageSource.camera).then((file) {
                    setState(() {
                      stagingImage = file.readAsBytesSync();
                      model.imageData = stagingImage;
                      file.deleteSync();
                    });
                  });
                },
                child: SizedBox(
                  width: 300.0, height: 300.0,
                  child:
                    Stack(children: <Widget>[
                      Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: 180.0,)),
                      staging.imageUrl == null
                        ? Image.memory(kTransparentImage)
                        : CachedNetworkImage(imageUrl: staging.imageUrl, width: 300.0, height: 300.0, fit: BoxFit.cover,),
                      Image.memory(stagingImage, width: 300.0, height: 300.0, fit: BoxFit.cover,),
                    ]
                  ),
                ),
              )
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

  Future<bool> _sureDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Are you sure?', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0),),
          actions: <Widget>[
            FlatButton(
              child: Text('Unsubscribe', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0),),
              onPressed: () { Navigator.of(context).pop(true); },
            ),
            FlatButton(
              color: Theme.of(context).primaryColor,
              child: Text('Cancel', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0, color: Colors.white),),
              onPressed: () { Navigator.of(context).pop(false); },
            ),
          ],
        );
      }
    );
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
                  if (await _sureDialog()) {
                    AppModel model = ModelFinder<AppModel>().of(context);
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