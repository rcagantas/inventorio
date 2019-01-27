import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/widgets/item_card.dart';

class ProductPage extends StatefulWidget {
  static final _repo = Injector.getInjector().get<RepositoryBloc>();
  final InventoryItem item;
  ProductPage(this.item);
  @override _ProductPageState createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _formKey = GlobalKey<FormState>();
  final double imageSize = 250.0;
  Product _cachedProduct;
  File _stagingImage;
  TextEditingController _brandCtrl, _nameCtrl, _variantCtrl;

  bool _isUnModified() {
    return _cachedProduct != null &&
      _cachedProduct.name == _nameCtrl.text &&
      _cachedProduct.brand == _brandCtrl.text &&
      _cachedProduct.variant == _variantCtrl.text &&
      _stagingImage == null;
  }

  bool _isUnset() {
    return _nameCtrl.text == '' &&
      _brandCtrl.text == '' &&
      _variantCtrl.text == '' &&
      _stagingImage == null;
  }


  @override
  void initState() {
    _brandCtrl    = TextEditingController();
    _nameCtrl     = TextEditingController();
    _variantCtrl  = TextEditingController();

    var callBack = () => setState(() {});

    _brandCtrl.addListener(callBack);
    _nameCtrl.addListener(callBack);
    _variantCtrl.addListener(callBack);

    _repo.getProductFuture(widget.item.inventoryId, widget.item.code).then((product) {
      setState(() {
        _cachedProduct = product;
        _brandCtrl.text = product.brand;
        _nameCtrl.text = product.name;
        _variantCtrl.text = product.variant;
      });
    });

    super.initState();
  }

  String _capitalizeWords(String sentence) {
    if (sentence == null || sentence.trim() == '') return null;
    return sentence.trim().split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ').trim();
  }

  TextFormField _fieldBuilder(TextEditingController controller, String labelText, Function clearCallback) {
    return TextFormField(
      maxLength: 60,
      controller: controller,
      keyboardType: TextInputType.text,
      decoration: new InputDecoration(
        labelText: labelText,
        suffixIcon: IconButton(
          icon: Icon(Icons.cancel, size: 18.0),
          onPressed: clearCallback
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.item.code}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(8.0),
          children: <Widget>[
            _fieldBuilder(_brandCtrl,   'Brand', () { _brandCtrl.clear(); }),
            _fieldBuilder(_nameCtrl,    'Product Name', () { _nameCtrl.clear(); }),
            _fieldBuilder(_variantCtrl, 'Variant/Flavor/Volume', () { _variantCtrl.clear(); }),
            FlatButton(
              onPressed: () {
                ImagePicker.pickImage(source: ImageSource.camera).then((file) {
                  if (file == null) return;
                  setState(() { _stagingImage = file; });
                });
              },
              child: SizedBox(
                width: imageSize, height: imageSize,
                child: ProductImage(widget.item, placeHolderSize: imageSize * .60, stagingImage: _stagingImage,)
              ),
            ),
            ListTile(title: Text('Tap to change image', textAlign: TextAlign.center,),),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.input),
        backgroundColor: _isUnModified() || _isUnset() ? Colors.grey : Theme.of(context).accentColor,
        onPressed: () async {
          if (_isUnModified() || _isUnset()) return;
          Product product = Product(
            code: widget.item.code,
            brand: _capitalizeWords(_brandCtrl.text),
            name: _capitalizeWords(_nameCtrl.text),
            variant: _capitalizeWords(_variantCtrl.text),
            imageUrl: _cachedProduct.imageUrl,
            isInitial: false,
            isLoading: false,
            imageFile: _stagingImage,
          );
          _bloc.actionSink(Action(Act.AddUpdateProduct, product));
          Navigator.pop(context, product);
        },
      ),
    );
  }
}
