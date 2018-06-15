class InventoryItemTile extends StatelessWidget {
  final AppModel appModel;
  final InventoryItem item;

  InventoryItemTile(this.appModel, this.item);

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
    print('Building tile for ${item.code}');
    Product product = appModel.getAssociatedProduct(item);
    Image imageResource = appModel.getImage(item.code);

    return Dismissible(
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
        appModel.removeItem(item.uuid);
        switch(direction) {
          case DismissDirection.startToEnd:
            Scaffold.of(context).showSnackBar(
              new SnackBar(
                content: new Text('Removed item ${product.name}'),
                action: new SnackBarAction(
                  label: "UNDO",
                  onPressed: () {
                    item.uuid = appModel.uuidGenerator.v4();
                    appModel.addItem(item);
                  },
                )
              )
            );
            break;
          default:
            Product editedProduct = await Navigator.push(
              context,
              new MaterialPageRoute(
                builder: (context) => new ProductPage(product, imageResource),
              )
            );
            if (editedProduct != null) {
              appModel.addProduct(editedProduct);
            }
            item.uuid = appModel.uuidGenerator.v4();
            appModel.addItem(item);
            break;
        }
      },
      key: new ObjectKey(item.uuid),
      child: new Row(
        children: <Widget>[
          new Expanded(
            flex: 1,
            child:
            imageResource == null?
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
                  image: imageResource.image,
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
  }
}

class ListingsPage extends StatelessWidget {
  final AppModel appModel;
  ListingsPage(this.appModel);

  @override
  Widget build(BuildContext context) {
    return new MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: 0.8),
      child: new Scaffold(
        drawer: new Drawer(
          child: new ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              ScopedModelDescendant<AppModel>(
                builder: (context, child, model) => DrawerHeader(
                  decoration: new BoxDecoration(color: Theme.of(context).primaryColor),
                  child: new ListTile(
                    leading: new CircleAvatar(
                      backgroundImage: NetworkImage(appModel.userImageUrl),
                    ),
                    title: new Text(
                      appModel.userDisplayName,
                      style: new TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 18.0,
                        color: Colors.white
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
        appBar: new AppBar(
          title: new Text(
            'Inventorio',
            style: new TextStyle(fontFamily: 'Montserrat'),
          ),
        ),
        body: ScopedModelDescendant<AppModel>(
          builder: (context, child, model) => ListView.builder(
            itemCount: model.inventoryItems.length,
            itemBuilder: (BuildContext context, int index) {
              return InventoryItemTile(model, model.inventoryItems[index]);
            })
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            InventoryItem item = await appModel.buildInventoryItem(context);

            if (item != null) {
              bool isProductIdentified = await appModel.isProductIdentified(item.code);
              if (!isProductIdentified) {
                Product product = await Navigator.push(
                  context,
                  new MaterialPageRoute(
                    builder: (context) => ProductPage(Product(code: item.code), null),
                  ),
                );
                if (product != null)
                  appModel.addProduct(product);
              }
              appModel.addItem(item);
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
  final Image imageResource;
  ProductPage(this.product, this.imageResource);
  @override State<ProductPage> createState() => new ProductPageState();
}

class ProductPageState extends State<ProductPage> {
  Product product;
  Image imageResource;
  Uuid uuidGenerator = new Uuid();

  @override
  void initState() {
    product = widget.product;
    imageResource = widget.imageResource;
    super.initState();
  }

  String _capitalizeWords(String sentence) {
    if (sentence == null) return sentence;
    return sentence.split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ').trim();
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
                  onChanged: (s) => product.brand = _capitalizeWords(s),
                  decoration: new InputDecoration(hintText: 'Brand'),
                  style: new TextStyle(fontFamily: 'Montserrat', color: Colors.black, fontSize: 18.0),
                ),
              ),
              new ListTile(
                title: new TextField(
                  controller: new TextEditingController(text: product.name),
                  onChanged: (s) => product.name = _capitalizeWords(s),
                  decoration: new InputDecoration(hintText: 'Name'),
                  style: new TextStyle(fontFamily: 'Montserrat', color: Colors.black, fontSize: 18.0),
                ),
              ),
              new ListTile(
                title: new TextField(
                  controller: new TextEditingController(text: product.variant),
                  onChanged: (s) => product.variant = _capitalizeWords(s),
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
                        imageResource = Image.file(file.renameSync(filePath));
                        product.imageFileName = "${product.code}_$uuid";
                      });
                    });
                  },
                  child: imageResource == null?
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
                        image: imageResource.image,
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