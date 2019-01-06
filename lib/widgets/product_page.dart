import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:image_picker/image_picker.dart';
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
  final _formKey = GlobalKey<FormState>();
  final double imageSize = 250.0;
  TextEditingController _brandCtrl, _nameCtrl, _variantCtrl;
  File _stagingImage;

  @override
  void initState() {
    Product product = _repo.getCachedProduct(widget.item.code);
    _brandCtrl    = TextEditingController(text: product.brand);
    _nameCtrl     = TextEditingController(text: product.name);
    _variantCtrl  = TextEditingController(text: product.variant);
    super.initState();
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
      appBar: AppBar(title: Text('${widget.item.code}'),),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(8.0),
          children: <Widget>[
            _fieldBuilder(_brandCtrl, 'Brand', () { _brandCtrl.clear(); }),
            _fieldBuilder(_nameCtrl, 'Product Name', () { _nameCtrl.clear(); }),
            _fieldBuilder(_variantCtrl, 'Variant/Flavor/Volume', () { _variantCtrl.clear(); }),
            Divider(),
            FlatButton(
              onPressed: () {
                ImagePicker.pickImage(source: ImageSource.camera).then((file) {
                  if (file == null) return;
                  setState(() { _stagingImage = file; });
                });
              },
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    height: imageSize,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.camera_alt, size: imageSize * .60, color: Colors.grey.shade400,),
                        Text('Add Photo'),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: imageSize, height: imageSize,
                    child: ProductImage(widget.item)
                  ),
                  SizedBox(
                    width: imageSize, height: imageSize,
                    child: _stagingImage == null
                      ? Container()
                      : Image.file(_stagingImage, width: imageSize, height: imageSize, fit: BoxFit.cover,),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
