import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventorio/model.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';

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
        theme: new ThemeData(),
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
                new Icon(Icons.delete, color: Colors.white),
                new Text('Remove',
                  textScaleFactor: 1.0,
                  style: new TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
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
                  textScaleFactor: 1.0,
                  style: new TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
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
              imageFile.existsSync()?
                new Container(
                  height: 80.0,
                  width: 80.0,
                  decoration: new BoxDecoration(
                    border: new Border.all(
                      color: Theme.of(context).canvasColor,
                      width: 5.0,
                    ),
                    image: new DecorationImage(
                      image: new FileImage(imageFile),
                      fit: BoxFit.cover
                    ),
                  ),
                ):
                new Icon(Icons.camera_alt, size: 80.0,),
              new Expanded(
                flex: 2,
                child: new Column(
                  children: <Widget>[
                    new Text(
                      product?.brand ?? '',
                      textScaleFactor: 1.0,
                      style: new TextStyle(fontFamily: 'Raleway'),
                      textAlign: TextAlign.center,
                    ),
                    new Text(
                      product?.name ?? item.code,
                      textScaleFactor: 1.3,
                      style: new TextStyle(fontFamily: 'Montserrat'),
                      textAlign: TextAlign.center,
                    ),
                    //new Text('${item.uuid}...', textScaleFactor: 0.5,)
                  ],
                ),
              ),
              new Expanded(
                child: new Text(
                  item.expiryDateString,
                  style: new TextStyle(
                    fontFamily: 'Raleway',
                    fontWeight: FontWeight.bold,
                  ),
                  textScaleFactor: 1.0,
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
    return new Scaffold(
      appBar: new AppBar(title: new Text('Inventorio', style: new TextStyle(fontFamily: 'Montserrat'),),),
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
                  builder: (context) => new ProductPage(new Product(code: item.code), model.getImage(item.code)),
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

  @override
  void initState() {
    product = new Product(
      code: widget.product.code,
      name: widget.product.name,
      brand: widget.product.brand);
    imageFile = widget.imageFile;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(product.name == ''? 'Edit Product': 'Add New Product')
      ),
      body: new Center(
        child: new ListView(
          children: <Widget>[
            new ListTile(
              title: new TextField(
                controller: new TextEditingController(text: product.brand),
                onChanged: (s) => product.brand = s.trim(),
                decoration: new InputDecoration(hintText: 'Brand'),
                inputFormatters: [new AutoCapWordsInputFormatter()],
              ),
            ),
            new ListTile(
              title: new TextField(
                controller: new TextEditingController(text: product.name),
                onChanged: (s) => product.name = s.trim(),
                decoration: new InputDecoration(hintText: 'Name'),
                inputFormatters: [new AutoCapWordsInputFormatter()],
              ),
            ),
            new ListTile(
              title: new FlatButton(
                onPressed: () async {
                  File file  = await ImagePicker.pickImage(source: ImageSource.camera);
                  file = await file.rename('${dirname(file.path)}/${product.code}.jpg');
                  print('Image for ${product.code} in ${file.path}');
                  setState(() { imageFile = file; });
                },
                child: imageFile.existsSync() ?
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
                  ):
                  new Icon(Icons.camera_alt, size: 150.0,),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: new FloatingActionButton(
        child: new Icon(Icons.add),
        onPressed: () { Navigator.pop(context, product); },
      ),
    );
  }
}

class AutoCapWordsInputFormatter extends TextInputFormatter {
  final RegExp capWordsPattern = new RegExp(r'(\w)(\w*\s*)');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = capWordsPattern
        .allMatches(newValue.text)
        .map((match) => match.group(1).toUpperCase() + match.group(2))
        .join();

    return new TextEditingValue(
      text: newText,
      selection: newValue.selection ?? const TextSelection.collapsed(offset: -1),
      composing: newText == newValue.text ? newValue.composing : TextRange.empty,
    );
  }
}