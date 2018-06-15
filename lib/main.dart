import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:inventorio/model.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        appBar: AppBar(title: Text('Inventorio', style: TextStyle(fontFamily: 'Montserrat'),),),
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
            InventoryItem item = await model.buildInventoryItem(context);
            if (item != null) {
              bool isProductIdentified = await model.isProductIdentified(item.code);

              if (!isProductIdentified) {
                Product product = await Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(Product(code: item.code)),),);
                if (product != null) model.addProduct(product);
              }
              model.addItem(item);
            }
          },
        ),
      ),
    );
  }
}

class InventoryItemTile extends StatelessWidget {
  InventoryItemTile(this.context, this.index);
  final BuildContext context;
  final int index;

  Color expiryColorScale(DateTime expiryDate) {
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
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2.0),
              child: CachedNetworkImage(imageUrl: product?.imageUrl, width: 80.0, height: 80.0, fit: BoxFit.cover,),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: <Widget>[
                product?.brand == null?   Container(): Text(product.brand,   style: TextStyle(fontFamily: 'Raleway',    fontSize: 15.0), textAlign: TextAlign.center,),
                product?.name == null?    Container(): Text(product.name,    style: TextStyle(fontFamily: 'Montserrat', fontSize: 18.0), textAlign: TextAlign.center,),
                product?.variant == null? Container(): Text(product.variant, style: TextStyle(fontFamily: 'Montserrat', fontSize: 15.0), textAlign: TextAlign.center,),
              ],
            )
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
            height: 80.0,
            width: 5.0,
            color: expiryColorScale(item.expiryDate),
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
              content: Text('Removed item ${product.name}'),
              action: SnackBarAction(
                label: "UNDO",
                onPressed: () {
                  item.uuid = model.uuidGenerator.v4();
                  model.addItem(item);
                },
              )
            )
          );
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(product),))
            .then((editedProduct) {
              if (editedProduct != null) model.addProduct(editedProduct);
              item.uuid = model.uuidGenerator.v4();
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
  }

  String _capitalizeWords(String sentence) {
    if (sentence == null) return sentence;
    return sentence.split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ').trim();
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
                onChanged: (s) => staging.brand = _capitalizeWords(s),
                decoration: InputDecoration(hintText: 'Brand'),
                style: TextStyle(fontFamily: 'Montserrat', color: Colors.black, fontSize: 18.0),
              ),
              trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () => _brand.clear())
            ),
            ListTile(
              title: TextField(
                controller: _name,
                onChanged: (s) => staging.name = _capitalizeWords(s),
                decoration: InputDecoration(hintText: 'Product Name'),
                style: TextStyle(fontFamily: 'Montserrat', color: Colors.black, fontSize: 18.0),
              ),
              trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () => _name.clear())
            ),
            ListTile(
              title: TextField(
                controller: _variant,
                onChanged: (s) => staging.variant = _capitalizeWords(s),
                decoration: InputDecoration(hintText: 'Variant'),
                style: TextStyle(fontFamily: 'Montserrat', color: Colors.black, fontSize: 18.0),
              ),
              trailing: IconButton(icon: Icon(Icons.cancel, size: 20.0,), onPressed: () => _variant.clear()),
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
                  height: 300.0, width: 300.0,
                  child:
                    Stack(children: <Widget>[
                      Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: 180.0,)),
                      CachedNetworkImage(imageUrl: staging.imageUrl, width: 300.0, height: 300.0, fit: BoxFit.cover,),
                      Image.memory(stagingImage, width: 300.0, height: 300.0, fit: BoxFit.cover,),
                    ]
                  ),
                ),
              )
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () => Navigator.pop(context, staging),
        ),
      )
    );
  }
}