import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventorio/model.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override State<MyApp> createState() => new MyAppState();
}

class MyAppState extends State<MyApp> {
  AppModel appModel;

  @override
  void initState() {
    appModel = new AppModel();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModel<AppModel>(
      model: appModel,
      child: new MaterialApp(
        title: 'Inventorio',
        home: new ListingsPage()
      )
    );
  }
}

class InventoryItemTile extends StatelessWidget {
  final InventoryItem item;

  InventoryItemTile(this.item);

  Color expiryColorScale(InventoryItem item) {
    DateTime today = new DateTime.now();
    Duration duration = item.expiryDate?.difference(today) ?? new Duration(days: 0);
    if (duration.inDays < 30) return Colors.redAccent;
    else if (duration.inDays < 90) return Colors.yellowAccent;
    return Colors.greenAccent;
  }

  List<Widget> buildProductIdentifier(Product product, InventoryItem item) {
    List<Widget> identifiers = new List();

    if (product == null) {
      identifiers.add(
        new Text(
          item.code,
          textAlign: TextAlign.center,
          style: new TextStyle(fontFamily: 'Montserrat', fontSize: 15.0),
        ),
      );
      return identifiers;
    }

    if (product.brand != null) {
      identifiers.add(
        new Text(
          product.brand,
          textAlign: TextAlign.center,
          style: new TextStyle(fontFamily: 'Raleway', fontSize: 17.0),
        )
      );
    }

    if (product.name != null) {
      identifiers.add(
        new Text(
          product.name,
          textAlign: TextAlign.center,
          style: new TextStyle(fontFamily: 'Montserrat', fontSize: 20.0),
        ),
      );
    }

    if (product.variant != null) {
      identifiers.add(
        new Text(
          product.variant,
          textAlign: TextAlign.center,
          style: new TextStyle(fontFamily: 'Montserrat', fontSize: 17.0),
        ),
      );
    }

    return identifiers;
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<AppModel>(
      builder: (context, child, model) {
        Product product = model.getAssociatedProduct(item);
        File imageFile = model.getImage(item.code);
        return new Dismissible(
          background: new Container(
            color: Colors.blueAccent,
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                new Icon(
                  Icons.delete,
                  color: Colors.white),
                new Text('Remove',
                  style: new TextStyle(
                    fontFamily: 'Montserrat',
                    color: Colors.white
                  ),
                ),
              ],
            ),
          ),
          secondaryBackground: new Container(
            color: Colors.lightBlueAccent,
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                new Text('Edit Product',
                  style: new TextStyle(
                    fontFamily: 'Montserrat',
                  ),
                ),
                new Icon(Icons.edit),
              ],
            ),
          ),
          onDismissed: (direction) async {
            model.removeItem(item.uuid);
            switch(direction) {
              case DismissDirection.startToEnd:
                Scaffold.of(context).showSnackBar(
                  new SnackBar(
                    content: new Text('Removed item ${product.name}'),
                    action: new SnackBarAction(
                      label: "UNDO",
                      onPressed: () {
                        item.uuid = model.uuidGenerator.v4();
                        model.addItem(item);
                      },
                    )
                  )
                );
                break;
              default:
                Product editedProduct = await Navigator.push(
                  context,
                  new MaterialPageRoute(
                    builder: (context) => new ProductPage(product, imageFile),
                  )
                );
                if (editedProduct != null) {
                  model.addProduct(editedProduct);
                }
                item.uuid = model.uuidGenerator.v4();
                model.addItem(item);
                break;
            }
          },
          key: new ObjectKey(item.uuid),
          child: new Row(
            children: <Widget>[
              new Expanded(
                flex: 1,
                child:
                imageFile == null?
                new Container(
                  height: 80.0,
                  width: 80.0,
                ):
                new Container(
                  height: 80.0,
                  width: 80.0,
                  decoration: new BoxDecoration(
                    border: new Border(
                      top:    BorderSide(width: 2.0, color: Theme.of(context).canvasColor),
                      left:   BorderSide(width: 2.0, color: Theme.of(context).canvasColor),
                      right:  BorderSide(width: 2.0, color: Theme.of(context).canvasColor),
                    ),
                    image: new DecorationImage(
                        image: new FileImage(imageFile),
                        fit: BoxFit.cover
                    ),
                  ),
                ),
              ),
              new Expanded(
                flex: 3,
                child: new Column(children: buildProductIdentifier(product, item),),
              ),
              new Expanded(
                flex: 1,
                child: Column(
                  children: <Widget>[
                    new Text(
                      item.expiryDateString.substring(0, 4),
                      style: new TextStyle(fontFamily: 'Raleway', fontSize: 15.0, fontWeight: FontWeight.bold),
                    ),
                    new Text(
                      item.expiryDateString.substring(5),
                      style: new TextStyle(fontFamily: 'Raleway', fontSize: 18.0, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              new SizedBox(
                width: 5.0,
                height: 80.0,
                child: new Container(color: expiryColorScale(item),)
              ),
            ],
          ),
        );
      },
    );
  }
}

class ListingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 0.8),
      child: new Scaffold(
        appBar: new AppBar(
          title: new Text(
            'Inventorio',
            style: new TextStyle(fontFamily: 'Montserrat'),
          ),
        ),
        body: new ScopedModelDescendant<AppModel>(
          builder: (context, child, model) => new ListView.builder(
            itemCount: model.inventoryItems.length,
            itemBuilder: (BuildContext context, int index) => new InventoryItemTile(model.inventoryItems[index])
          ),
        ),
        floatingActionButton: new ScopedModelDescendant<AppModel>(
          builder: (context, child, model) => new FloatingActionButton(
            onPressed: () async {
              InventoryItem item = await model.addItemFlow(context);
              bool isIdentified = await model.isProductIdentified(item.code);
              if (!isIdentified) {
                Product product = await Navigator.push(
                  context,
                  new MaterialPageRoute(
                    builder: (context) => new ProductPage(new Product(code: item.code), null),
                  )
                );
                if (product != null) model.addProduct(product);
                else model.removeItem(item.uuid);
              }
            },
            child: new Icon(Icons.add_a_photo),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
}

class ProductPage extends StatefulWidget {
  final Product product;
  final File imageFile;
  ProductPage(this.product, this.imageFile);
  @override State<ProductPage> createState() => new ProductPageState();
}

class ProductPageState extends State<ProductPage> {
  Product product;
  File imageFile;
  Uuid uuidGenerator = new Uuid();

  @override
  void initState() {
    product = widget.product;
    imageFile = widget.imageFile;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return new MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 0.8),
      child: new Scaffold(
        appBar: new AppBar(
          title: new Text(
            product.name != ''? 'Edit Product': 'Add New Product',
            style: new TextStyle(fontFamily: 'Montserrat'),
          ),
        ),
        body: new Center(
          child: new ListView(
            children: <Widget>[
              new ListTile(
                dense: true,
                title: new Text(
                  product.code,
                  textAlign: TextAlign.center,
                  style: new TextStyle(fontFamily: 'Montserrat'),
                ),
              ),
              new ListTile(
                title: new TextField(
                  controller: new TextEditingController(text: product.brand),
                  onChanged: (s) => product.brand = s.trim(),
                  decoration: new InputDecoration(hintText: 'Brand'),
                  style: new TextStyle(fontFamily: 'Montserrat', color: Colors.black, fontSize: 18.0),
                ),
              ),
              new ListTile(
                title: new TextField(
                  controller: new TextEditingController(text: product.name),
                  onChanged: (s) => product.name = s.trim(),
                  decoration: new InputDecoration(hintText: 'Name'),
                  style: new TextStyle(fontFamily: 'Montserrat', color: Colors.black, fontSize: 18.0),
                ),
              ),
              new ListTile(
                title: new TextField(
                  controller: new TextEditingController(text: product.variant),
                  onChanged: (s) => product.variant = s.trim(),
                  decoration: new InputDecoration(hintText: 'Variant'),
                  style: new TextStyle(fontFamily: 'Montserrat', color: Colors.black, fontSize: 18.0),
                ),
              ),
              new ListTile(
                title: new FlatButton(
                  onPressed: () {
                    ImagePicker.pickImage(source: ImageSource.camera).then((file) {
                      String uuid = uuidGenerator.v4();
                      String filePath = '${dirname(file.path)}/${product.code}_$uuid.jpg';
                      setState(() {
                        imageFile = file.renameSync(filePath);
                        product.imageFileName = "${product.code}_$uuid";
                      });
                    });
                  },
                  child: imageFile == null?
                  new Icon(
                    Icons.camera_alt,
                    color: Colors.grey,
                    size: 150.0,
                  ):
                  new Container(
                      height: 200.0,
                      width: 200.0,
                      decoration: new BoxDecoration(
                        image: new DecorationImage(
                          image: new FileImage(imageFile),
                          fit: BoxFit.cover
                        ),
                      ),
                      margin: const EdgeInsets.only(top: 20.0),
                    ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: new FloatingActionButton(
          child: new Icon(Icons.add),
          onPressed: () { Navigator.pop(context, product); },
        ),
      ),
    );
  }
}