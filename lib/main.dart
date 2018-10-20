import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventorio/definitions.dart';
import 'package:inventorio/inventory_model.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr_mobile_vision/qr_camera.dart';
import 'package:scoped_model/scoped_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:date_utils/date_utils.dart';
import 'package:loader_search_bar/loader_search_bar.dart';


void main() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then(
      (_) => runApp(InventoryApp()));
}

class InventoryApp extends StatefulWidget {
  @override
  State<InventoryApp> createState() => InventoryAppState();
}

class InventoryAppState extends State<InventoryApp> {
  final InventoryModel inventoryModel = InventoryModel();

  @override
  Widget build(BuildContext context) {
    return ScopedModel<InventoryModel>(
      model: inventoryModel,
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          selectedRowColor: Colors.lightBlueAccent,
          primaryColor: Colors.blue.shade700,
          accentColor: Colors.blue.shade700,
          accentTextTheme: TextTheme(
            button: ThemeData.light().accentTextTheme.button.copyWith(fontFamily: 'Prompt', fontSize: 18.0), // floating button
          ),
          primaryTextTheme: TextTheme(
            title: ThemeData.light().primaryTextTheme.title.copyWith(fontFamily: 'Prompt', fontSize: 19.0, fontWeight: FontWeight.bold), // appbar
            body2: ThemeData.light().primaryTextTheme.body2.copyWith(fontFamily: 'Prompt', fontSize: 16.0, color: Colors.white, fontWeight: FontWeight.bold), // accountName
            body1: ThemeData.light().primaryTextTheme.body1.copyWith(fontFamily: 'Prompt', fontSize: 16.0, color: Colors.white), // accountEmail
          ),
          textTheme: TextTheme(
            title: ThemeData.light().textTheme.title.copyWith(fontFamily: 'Prompt', fontSize: 16.0), // dialog
            subhead: ThemeData.light().textTheme.subhead.copyWith(fontFamily: 'Prompt', fontSize: 16.0), // welcome
            body2: ThemeData.light().textTheme.body2.copyWith(fontFamily: 'Prompt', fontSize: 16.0), // title
            body1: ThemeData.light().textTheme.body1.copyWith(fontFamily: 'Raleway', fontSize: 15.0), // subtitle
            caption: ThemeData.light().textTheme.button.copyWith(fontFamily: 'Prompt', fontSize: 16.0, color: Colors.grey.shade600),
            button: ThemeData.light().textTheme.button.copyWith(fontFamily: 'Prompt', fontSize: 16.0),
          ),
        ),
        title: 'Inventorio',
        home: ListingsPage(),
      ),
    );
  }
}

class _SearchDelegate extends SearchDelegate<InventoryItem> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          InventoryModel searchModel = ScopedModel.of(context);
          searchModel.setFilter(null);
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    InventoryModel model = ScopedModel.of(context);
    return IconButton(
      tooltip: 'Back',
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        model.setFilter(null);
        close(context, null);
      },
    );
  }

  Widget _buildList(BuildContext context) {
    InventoryModel model = ScopedModel.of(context);
    model.setFilter(query);
    return ListView.builder(
      itemCount: model.selected?.items?.length ?? 0,
      itemBuilder: (context, index) {
        return InventoryTile(model.selected.items[index]);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context);
  }

}

class ListingsPage extends StatelessWidget {
  final _searchDelegate = _SearchDelegate();
  @override
  Widget build(BuildContext context) {
    InventoryModel _searchModel = ScopedModel.of(context);
    return Scaffold(
      appBar: AppBar(
        title: ScopedModelDescendant<InventoryModel>(
          builder: (context, child, model) => Text(model.selected?.details?.name ?? 'Inventory'),
        ),
        actions: <Widget>[
          ScopedModelDescendant<InventoryModel>(
            builder: (context, child, model) {
              return IconButton(
                icon: _searchModel?.selected?.sortAlpha ?? false
                    ? Icon(Icons.sort_by_alpha)
                    : Icon(Icons.sort),
                onPressed: () {
                  _searchModel.toggleSort();
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed:() async {
              showSearch(context: context, delegate: _searchDelegate);
            }
          )
        ],
      ),
      body: ScopedModelDescendant<InventoryModel>(
          builder: (context, child, model) {
            return (model.userAccount == null
                || model.selected?.items?.length == 0
            )
            ? _buildWelcome()
            : ListView.builder(
                itemCount: (model.selected?.items?.length ?? 0) + 1, // add space at the bottom
                itemBuilder: (context, index) {
                  return index >= (model?.selected?.items?.length ?? 0)
                  ? Container(height: 80.0,)
                  : InventoryTile(model.selected.items[index]);
                },
            );
          }
      ),
      drawer: Drawer(
        child: ScopedModelDescendant<InventoryModel>(
          builder: (context, child, model) => ListView(
            padding: EdgeInsets.zero,
            children: _buildDrawerItems(context, model),
          ),
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) => FloatingActionButton.extended(
            onPressed: () { _addItem(context);},
            icon: Icon(Icons.add_a_photo),
            label: Text('Scan Barcode')
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.add_a_photo, color: Colors.grey.shade400, size: 150.0,),
          ListTile(title: Text('Welcome to Inventorio', textAlign: TextAlign.center,)),
          ListTile(title: Text('Scanned items and expiration dates will appear here. ', textAlign: TextAlign.center,)),
          ListTile(title: Text('Scan new items by clicking the button below.', textAlign: TextAlign.center,)),
        ],
      ),
    );
  }

  List<Widget> _buildDrawerItems(BuildContext context, InventoryModel model) {
    List<Widget> widgets = [
      UserAccountsDrawerHeader(
        accountName: Text(model?.selected?.details?.name ?? 'Current Inventory Name'),
        accountEmail: Text('${model?.selected?.items?.length ?? '?'} items',),
        currentAccountPicture: CircleAvatar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          backgroundImage: AssetImage('resources/icons/icon.png'),
        ),
      ),
      ListTile(
        title: Text(model.isSignedIn? 'Log out': 'Login with Google',),
        subtitle: !model.isSignedIn? null: Text('${model.userDisplayName?? ''}'),
        onTap: () {
          Navigator.of(context).pop();
          if (model.isSignedIn) {
            sureDialog(context, 'Login with another account?', 'Sign-out', 'Cancel').then((sure) {
              if (sure) model.signOut();
            });
          } else {
            model.signIn();
          }
        },
      ),
      ExpansionTile(
        title: Text('Inventory Management',),
        children: <Widget>[
          ListTile(
            enabled: model.isSignedIn,
            dense: true,
            title: Text('Create New Inventory'),
            onTap: () async {
              Navigator.of(context).pop();
              InventoryDetails inventory = await Navigator.push(context,
                  MaterialPageRoute(builder: (context) => InventoryDetailsPage(null))
              );
              model.addInventory(inventory, createNew: true).catchError((error) {
                Scaffold.of(context).showSnackBar(SnackBar(content: Text("Error: $error")));
              });
            },
          ),
          ListTile(
            enabled: model.isSignedIn,
            dense: true,
            title: Text('Scan Existing Inventory Code'),
            onTap: () async {
              Navigator.of(context).pop();
              String code = await Navigator.push(context,
                  MaterialPageRoute(builder: (context) => ScanningPage())
              );
              bool valid = await model.scanInventory(code);
              if (!valid) { sureDialog(context, 'Invalid code $code. ', null, 'OK'); }
            },
          ),
          ListTile(
            enabled: model.isSignedIn,
            dense: true,
            title: Text('Edit/Share Inventory'),
            onTap: () async {
              Navigator.of(context).pop();
              InventoryDetails details = model.selected.details;
              InventoryDetails edited = await Navigator.push(context,
                  MaterialPageRoute(builder: (context) => InventoryDetailsPage(details),)
              );
              model.addInventory(edited);
            },
          ),
          ListTile(
              dense: true,
              title: Text('Logs'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (context) => LogPage()));
              }
          ),
        ],
      ),
      Divider()
    ];

    var inventoryDrawerList = model.inventories?.values?.toList() ?? [];
    inventoryDrawerList.sort((inv1, inv2) => inv2.items.length.compareTo(inv1.items.length));

    inventoryDrawerList.forEach((inventory) {
      String inventoryId = inventory?.details?.uuid;
      widgets.add(
          ListTile(
            selected: inventoryId == model.selected?.details?.uuid,
            title: Text(inventory.details.name ?? 'Inventory', softWrap: false,),
            subtitle: Text('${inventory.items.length} items', softWrap: false,),
            onTap: () async {
              Navigator.of(context).pop();
              // let the animation finish before changing the inventory.
              Future.delayed(Duration(milliseconds: 300), () {
                model.changeCurrentInventory(inventoryId);
              });
            },
          )
      );
    });
    return widgets;
  }

  static Future<bool> sureDialog(BuildContext context, String question, String yes, String no) async {
    return showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text(question,),
            actions: <Widget>[
              yes == null ? Container():
              FlatButton(
                child: Text(yes),
                onPressed: () { Navigator.of(context).pop(true); },
              ),
              FlatButton(
                color: Theme.of(context).primaryColor,
                child: Text(no, style: Theme.of(context).textTheme.button.copyWith(color: Colors.white),),
                onPressed: () { Navigator.of(context).pop(false);},
              ),
            ],
          );
        }
    );
  }

  void _addItem(BuildContext context) async {
    InventoryModel model = ScopedModel.of(context);
    if (!model.isSignedIn) {
      model.signIn();
      return;
    }

    print('Scanning new item...');
    String code = await Navigator.push(context, MaterialPageRoute(builder: (context) => ScanningPage()));
    if (code == null) return;
    if (code.contains('/')) {
      print('Has a slash. Invalid');
      Scaffold.of(context).showSnackBar(
          SnackBar(
              content: Text("Invalid code: $code"),
              duration: Duration(seconds: 5),
              action: SnackBarAction(label: "COPY", onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
              },)
          )
      );
      return;
    }

    print('Attempting to add new item');
    Navigator.push(context, MaterialPageRoute(builder: (context) => InventoryAddPage(code)));
  }
}

class InventoryTile extends StatelessWidget {
  final InventoryItem item;
  InventoryTile(this.item);

  @override
  Widget build(BuildContext context) {
    InventoryModel model = ScopedModel.of(context);
    Product product = model.selected.getAssociatedProduct(item.code);
    TextStyle body1Bold = Theme.of(context).textTheme.body1
        .copyWith(fontWeight: FontWeight.bold);

    TextAlign alignment = TextAlign.center;
    double textScaleFactor = MediaQuery.of(context).textScaleFactor;
    double adjustedHeight = 98.0 * textScaleFactor;

    return Slidable(
      delegate: SlidableDrawerDelegate(),
      actionExtentRatio: 0.25,
      child: FlatButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          if (product == null) return;
          Navigator.push(context, MaterialPageRoute(
              builder: (context) => InventoryAddPage(
                product.code,
                replace: item,
                productReference: product,
              ))
          );
        },
        child: Container(
          padding: EdgeInsets.only(bottom: 2.0),
          child: Row(
            children: <Widget>[
              Hero(
                tag: item.uuid,
                child: SizedBox(
                  height: adjustedHeight,
                  width: 80.0,
                  child: product?.imageUrl == null || product?.imageUrl == ''
                  ? Center(child: Icon(Icons.camera_alt, color: Colors.grey.shade400))
                  : CachedNetworkImage(
                      imageUrl: product?.imageUrl ?? '', fit: BoxFit.cover,
                      placeholder: Center(child: Icon(Icons.camera_alt, color: Colors.grey)),
                      errorWidget: Center(child: Icon(Icons.error_outline, color: Colors.grey)),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(0.5),
                  child: buildProductLabel(context, product, item.code),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text('${item.year}', style: body1Bold, textAlign: alignment,),
                    Text('${item.month} ${item.day}', style: body1Bold, textAlign: alignment,),
                  ],
                ),
              ),
              Container(
                width: 5.0, height: adjustedHeight,
                color: _expiryColorScale(item.daysFromToday),
              ),
            ],
          ),
        ),
      ),
      key: ObjectKey(item.uuid),
      secondaryActions: <Widget>[
        IconSlideAction(
          caption: 'Edit Product',
          color: Colors.lightBlueAccent,
          icon: Icons.edit,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (context) => ProductPage(product, heroCode: item.uuid,))
              );
            }
        ),
        IconSlideAction(
          caption: 'Delete',
          color: Colors.red,
          icon: Icons.delete,
          onTap: () {
            InventoryModel model = ScopedModel.of(context);
            model.removeItem(item);
            Scaffold.of(context).showSnackBar(
                SnackBar(
                    content: Text('Removed item ${product?.name}'),
                    action: SnackBarAction(
                      label: "UNDO",
                      onPressed: () {
                        model.addAsNewItem(item); // undo remove
                      },
                    )
                )
            );
          },
        ),
      ],
    );
  }

  Color _expiryColorScale(int days) {
    if (days < 30) return Colors.redAccent;
    else if (days < 90) return Colors.yellowAccent;
    return Colors.greenAccent;
  }

  static Widget buildProductLabel(BuildContext context, Product product, String code) {
    TextStyle body1 = Theme.of(context).textTheme.body1;
    TextStyle body2 = Theme.of(context).textTheme.body2;

    List<Widget> labels = [
      Text('${product?.brand ?? ''}',   style: body1, textAlign: TextAlign.center,),
      Text('${product?.name ?? ''}',    style: body2, textAlign: TextAlign.center,),
      Text('${product?.variant ?? ''}', style: body1, textAlign: TextAlign.center,),
    ];

    labels.retainWhere((widget) {
      Text text = widget as Text;
      return text.data.isNotEmpty;
    });

    if (labels.length == 0) {
      labels.add(Text('$code',          style: body1, textAlign: TextAlign.center,));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: labels,
    );
  }
}

class ProductPage extends StatefulWidget {
  final Product product;
  final String heroCode;
  ProductPage(this.product, {this.heroCode});
  @override State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  String _code, _imageUrl;
  TextEditingController _brandCtrl, _nameCtrl, _variantCtrl;
  File _stagingImage;
  final double imageSize = 250.0;

  bool _isUnModified() {
    return widget.product != null &&
      (widget.product.name?.toLowerCase() ?? '') == _nameCtrl.text.toLowerCase() &&
      (widget.product.brand?.toLowerCase() ?? '') == _brandCtrl.text.toLowerCase() &&
      (widget.product.variant?.toLowerCase() ?? '') == _variantCtrl.text.toLowerCase() &&
      _stagingImage == null;
  }

  bool _isUnset() {
    return _nameCtrl.text == null &&
      _brandCtrl.text == null &&
      _variantCtrl.text == null &&
      _stagingImage == null;
  }

  @override
  void initState() {
    _code = widget.product.code;
    _imageUrl = widget.product.imageUrl;
    _brandCtrl    = TextEditingController(text: widget.product.brand);
    _nameCtrl     = TextEditingController(text: widget.product.name);
    _variantCtrl  = TextEditingController(text: widget.product.variant);

    var callBack = () => setState(() {});
    _brandCtrl.addListener(callBack);
    _nameCtrl.addListener(callBack);
    _variantCtrl.addListener(callBack);
    super.initState();
  }

  String capitalizeWords(String sentence) {
    if (sentence == null || sentence.trim() == '') return null;
    return sentence.trim().split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_code'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (_stagingImage != null) print('Deleting ${_stagingImage?.path}');
            _stagingImage?.delete();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Form(
        child: ListView(
          padding: EdgeInsets.all(8.0),
          children: <Widget>[
            TextFormField(
              maxLength: 60,
              controller: _brandCtrl,
              keyboardType: TextInputType.text,
              decoration: new InputDecoration(
                labelText: 'Brand',
                suffixIcon: IconButton(
                    icon: Icon(Icons.cancel, size: 18.0),
                    onPressed: () { _brandCtrl.clear(); }
                ),
              ),
            ),
            TextFormField(
              maxLength: 60,
              controller: _nameCtrl,
              keyboardType: TextInputType.text,
              decoration: new InputDecoration(
                labelText: 'Product Name',
                suffixIcon: IconButton(
                    icon: Icon(Icons.cancel, size: 18.0),
                    onPressed: () { _nameCtrl.clear(); }
                ),
              ),
            ),
            TextFormField(
              maxLength: 60,
              controller: _variantCtrl,
              keyboardType: TextInputType.text,
              decoration: new InputDecoration(
                labelText: 'Variant/Flavor/Volume',
                suffixIcon: IconButton(
                    icon: Icon(Icons.cancel, size: 18.0),
                    onPressed: () { _variantCtrl.clear(); }
                ),
              ),
            ),
            Divider(),
            FlatButton(
              onPressed: () {
                ImagePicker.pickImage(source: ImageSource.camera).then((file) {
                  if (file == null) return;
                  setState(() { _stagingImage = file; });
                });
              },
              child: Hero(
                tag: widget.heroCode,
                child: Center(
                  child: Stack(
                    alignment: AlignmentDirectional.center,
                    children: <Widget>[
                      Icon(Icons.camera_alt, size: imageSize * .60, color: Colors.grey.shade400,),
                      Padding(
                        padding: const EdgeInsets.only(top: 130.0),
                        child: Text('Add Photo', style: Theme.of(context).textTheme.body1,),
                      ),
                      _imageUrl == null || _imageUrl == '' ? Container(): CachedNetworkImage(
                        imageUrl: _imageUrl , fit: BoxFit.cover,
                        height: imageSize, width: imageSize,
                        placeholder: Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: imageSize * .60,)),
                        errorWidget: Center(child: Icon(Icons.error_outline, color: Colors.grey, size: imageSize * .60,)),
                      ),
                      _stagingImage == null
                      ? Container()
                      : Image.file(_stagingImage, width: imageSize, height: imageSize, fit: BoxFit.cover,)
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.input),
        backgroundColor: _isUnModified() || _isUnset()
            ? Colors.grey
            : Theme.of(context).accentColor,
        onPressed: () {
          if (_isUnModified() || _isUnset()) return;
          InventoryModel model = ScopedModel.of(context);
          Product product = model.insertUpdateProduct(
              _code,
              capitalizeWords(_brandCtrl.text),
              capitalizeWords(_nameCtrl.text),
              capitalizeWords(_variantCtrl.text),
              _imageUrl,
              _stagingImage);
          Navigator.of(context).pop(product);
        }
      ),
    );
  }
}

class ScanningPage extends StatefulWidget {
  @override State<ScanningPage> createState() => _ScanningPageState();
}

class _ScanningPageState extends State<ScanningPage> {
  String code;

  void _onDetection(BuildContext context, String code) {
    if (this.code == null) {
      print('Popping code $code');
      this.code = code;
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Scan Barcode', style: Theme.of(context).primaryTextTheme.title),),
        body: Column(
          children: <Widget>[
            Container(
                height: 300.0,
                child: QrCamera(qrCodeCallback: (code) { _onDetection(context, code); })
            ),
            ListTile(title: Text('Center Barcode/QR in Window', textAlign: TextAlign.center,)),
          ],
        )
    );
  }
}

class InventoryAddPage extends StatefulWidget {
  final String code;
  final InventoryItem replace;
  final Product productReference;
  InventoryAddPage(this.code, {this.replace, this.productReference});
  @override State<InventoryAddPage> createState() => _InventoryAddPageState();
}

class _InventoryAddPageState extends State<InventoryAddPage> {

  List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct','Nov','Dec',];
  FixedExtentScrollController yearController, monthController, dayController;
  int yearIndex, monthIndex, dayIndex;
  DateTime selectedYearMonth;
  DateTime ref;
  Product staging;
  bool isLoading = true;
  bool known = false;

  bool _isUnModified() {
    if (widget.replace == null) return false;
    return widget.replace != null &&
        widget.replace.expiryDate.year == yearIndex &&
        widget.replace.expiryDate.month == monthIndex &&
        widget.replace.expiryDate.day == dayIndex;
  }

  @override
  void initState() {
    ref = widget.replace?.expiryDate ?? DateTime.now();
    yearController = FixedExtentScrollController(initialItem: ref.year - DateTime.now().year);
    monthController = FixedExtentScrollController(initialItem: ref.month - 1);
    dayController = FixedExtentScrollController(initialItem: ref.day - 1);
    selectedYearMonth = DateTime(ref.year, ref.month);
    yearIndex = ref.year;
    monthIndex = ref.month;
    dayIndex = ref.day;

    if (widget.productReference != null) {
      setStaging(widget.productReference);
    } else {
      InventoryModel model = ScopedModel.of(context);
      model.identifyProduct(widget.code).then((product) {
        setState(() {
          setStaging(product);
        });
      });
    }

    super.initState();
  }

  void setStaging(Product product) {
    this.staging = product;
    this.known = staging != null;
    this.isLoading = false;
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

  Widget imageSupplier(BuildContext context) {
    InventoryModel model = ScopedModel.of(context);
    if (model.selected.replacedImage.containsKey(widget.code)) {
      return Image.memory(model.selected.replacedImage[widget.code], fit: BoxFit.cover,);
    } else if (staging?.imageUrl != null && staging?.imageUrl != '') {
      return CachedNetworkImage(
        imageUrl: staging?.imageUrl ?? '', fit: BoxFit.cover,
        placeholder: Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: 80.0,)),
        errorWidget: Center(child: Icon(Icons.error_outline, color: Colors.grey, size: 80.0,)));
    }
    return Icon(Icons.camera_alt, color: Colors.grey.shade400, size: 80.0,);
  }

  @override
  Widget build(BuildContext context) {
    TextStyle pickerStyle = Theme.of(context).textTheme.body2.copyWith(fontSize: 25.0);
    return Scaffold(
        appBar: AppBar(title: Text(widget.code ?? '')),
        body: ListView(
          children: <Widget>[
            Container(
              height: 160.0,
              child: ScopedModelDescendant<InventoryModel>(
                builder: (context, child, model) {
                  return FlatButton(
                    onPressed: () async {
                      Product temp = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) =>
                              ProductPage(staging != null
                                  ? staging
                                  : Product(code: widget.code),
                                heroCode: widget.replace?.uuid ?? widget.code,)
                          )
                      ); // edit from item
                      if (temp != null) setState(() { setStaging(temp); });
                    },
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: 2,
                          child: Hero(
                            tag: widget.replace?.uuid ?? widget.code,
                            child: SizedBox(
                                width: 130.0, height: 130.0,
                                child: imageSupplier(context)
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: isLoading
                                ? Center(child: CircularProgressIndicator())
                                : staging == null
                                  ? Text('Add Product Information', style: pickerStyle, textAlign: TextAlign.center,)
                                  : InventoryTile.buildProductLabel(context, staging, widget.code),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
            Divider(),
            Row(
              children: <Widget>[
                _createPicker(
                  context,
                  onChange: (index) {
                    setState(() {
                      yearIndex = index + DateTime.now().year;
                      selectedYearMonth = DateTime(yearIndex, monthIndex);
                    });
                  },
                  scrollController: yearController,
                  children: List<Widget>.generate(10, (int index) {
                    return Center(child: Text('${index + DateTime.now().year}', style: pickerStyle));
                  })
                ),
                _createPicker(
                  context,
                  onChange: (index) {
                    setState(() {
                      monthIndex = index + 1;
                      selectedYearMonth = DateTime(ref.year, monthIndex);
                    });
                  },
                  scrollController: monthController,
                  children: List<Widget>.generate(12, (int index) {
                    return Center(child: Text(monthNames[index], style: pickerStyle));
                  })
                ),
                _createPicker(
                  context,
                  onChange: (index) { setState(() { dayIndex = index + 1; }); },
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
              ? await Navigator.push(context, MaterialPageRoute(builder: (context) =>
                ProductPage(
                  Product(code: widget.code),
                  heroCode: widget?.replace?.uuid,)))
              : staging;

            if (staging == null) return;
            if (_isUnModified()) return;

            DateTime expiryDate = DateTime(yearIndex, monthIndex, dayIndex);
            InventoryModel model = ScopedModel.of(context);
            InventoryItem item = model.buildInventoryItem(staging.code, expiryDate, uuid: widget?.replace?.uuid);
            if (item != null) { model.addItem(item); }
            Navigator.of(context).pop();
          },
          backgroundColor: isLoading || _isUnModified()? Colors.grey: Theme.of(context).primaryColor,
        ),
    );
  }
}

class InventoryDetailsPage extends StatefulWidget {
  InventoryDetailsPage(this.inventoryDetails);
  final InventoryDetails inventoryDetails;
  @override State<InventoryDetailsPage> createState() => _InventoryDetailsState();
}

class _InventoryDetailsState extends State<InventoryDetailsPage> {
  InventoryDetails staging;
  TextEditingController _name;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    staging = widget.inventoryDetails == null
        ? InventoryDetails(uuid: InventoryModel.generateUuid())
        : widget.inventoryDetails;
    _name = TextEditingController(text: staging.name);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inventory Settings')),
      body: Container(
        padding: EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                maxLength: 60,
                controller: _name,
                keyboardType: TextInputType.text,
                decoration: new InputDecoration(
                  labelText: 'New Inventory Name',
                  suffixIcon: IconButton(
                      icon: Icon(Icons.cancel, size: 18.0),
                      onPressed: () { _name.clear(); }
                  ),
                ),
              ),
              Divider(),
              ListTile(title: Text('Share this inventory by scanning the image below.', textAlign: TextAlign.center,)),
              Center(
                child: QrImage(
                  data: staging.uuid,
                  size: 250.0,
                ),
              ),
              Text(staging.uuid, textAlign: TextAlign.center,),
              widget.inventoryDetails == null
                  ? Container(width: 0.0, height: 0.0,)
                  : ListTile(
                title: RaisedButton(
                    child: Text('Unsubscribe to inventory'),
                    onPressed: () async {
                      InventoryModel model = ScopedModel.of(context);
                      if (await ListingsPage.sureDialog(context, 'Are you sure?', 'Unsubscribe', 'Cancel')) {
                        model.unsubscribeInventory(staging.uuid);
                        Navigator.pop(context, null);
                      }
                    }
                ),
              ),
            ],
          ),
        )
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.input),
        onPressed: () {
          staging.name = _name.text;
          Navigator.pop(context, staging);
        },
      ),
    );
  }
}

class LogPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Logs', style: Theme.of(context).primaryTextTheme.title,),),
      body: ScopedModelDescendant<InventoryModel>(
        builder: (context, child, model) => ListView.builder(
            itemCount: model.logMessages.length,
            itemBuilder: (context, index) {
              String time = model.logMessages[index].substring(0, 19);
              String message = model.logMessages[index].substring(28);
              TextStyle style = ThemeData.light().textTheme.body2.copyWith(fontSize: 12.0); // default theme
              return Padding(
                padding: const EdgeInsets.only(bottom: 3.0),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text('$time', style: style, textAlign: TextAlign.center,),),
                    Expanded(child: Text('$message', style: style), flex: 3,),
                  ],
                ),
              );
            }
        ),
      ),
    );
  }
}