import 'package:dart_extensions_methods/dart_extensions_methods.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:inventorio/models/inv_product.dart';
import 'package:inventorio/providers/inv_state.dart';
import 'package:inventorio/utils/forms/form_ext_validator.dart';
import 'package:inventorio/widgets/product_edit/custom_image_form_field.dart';
import 'package:provider/provider.dart';

class ProductEditPage extends StatefulWidget {

  static const ROUTE = '/productEdit';

  @override
  _ProductEditPageState createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {

  InvProductBuilder productBuilder;

  final _formKey = GlobalKey<FormState>();
  bool _validFab;

  final _brandFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _variantFocus = FocusNode();

  static const TOO_LONG = 'Text is too long';
  static const MAX_LEN = 60;
  static const REQUIRED = 'Field is required';

  void checkValidity() {
    var productValid = productBuilder.name.isNotNullOrEmpty();
    _validFab = _formKey.currentState?.validate() ?? productValid;
  }

  @override
  void initState() {
    productBuilder = InvProductBuilder();
    super.initState();
  }

  @override
  void dispose() {
    _brandFocus.dispose();
    _nameFocus.dispose();
    _variantFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    productBuilder = ModalRoute.of(context).settings.arguments;
    checkValidity();

    return Consumer<InvState>(
      builder: (context, invState, child) => Scaffold(
        appBar: AppBar(
          title: Text('Edit Product Details'),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: _validFab
              ? Theme.of(context).accentColor
              : Theme.of(context).disabledColor,

          onPressed: () async {
            if (_formKey.currentState.validate()) {
              _formKey.currentState.save();

              invState.updateProduct(productBuilder);
              Navigator.of(context).pop();
            }

          },
          child: Icon(Icons.cloud_upload),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {

                var orientation = MediaQuery.of(context).orientation;

                var children = <Widget>[
                  CustomImageFormField(
                    imageAttribute: 'imageFile',
                    resizedAttribute: 'resizedImageFileFuture',
                    heroCode: productBuilder.heroCode,
                    initialUrl: productBuilder.imageUrl,
                    onChanged: (imageFile, resizedImageFileFuture) => setState(() {
                      productBuilder.imageFile = imageFile;
                      productBuilder.resizedImageFileFuture = resizedImageFileFuture;
                    }),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text('${productBuilder.code}',
                        style: Theme.of(context).textTheme.caption,
                        textAlign: TextAlign.center,
                      ),
                      TextFormField(
                        initialValue: productBuilder.brand,
                        focusNode: _brandFocus,
                        decoration: InputDecoration(labelText: 'Brand name'),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (value) => FocusScope.of(context).requestFocus(_nameFocus),
                        onChanged: (value) => setState(() { productBuilder.brand = value; }),
                        validator: FormExtValidator.buildValidator([
                          FormExtValidator.maxLength(MAX_LEN, errorText: TOO_LONG),
                        ]),
                      ),
                      TextFormField(
                        initialValue: productBuilder.name,
                        focusNode: _nameFocus,
                        decoration: InputDecoration(labelText: 'Product Name'),
                        onChanged: (value) => setState(() {
                          productBuilder.name = value;
                          checkValidity();
                        }),
                        textCapitalization: TextCapitalization.words,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (value) => FocusScope.of(context).requestFocus(_variantFocus),
                        validator: FormExtValidator.buildValidator([
                          FormExtValidator.maxLength(MAX_LEN, errorText: TOO_LONG),
                          FormExtValidator.required(errorText: REQUIRED),
                        ]),
                      ),
                      TextFormField(
                        initialValue: productBuilder.variant,
                        focusNode: _variantFocus,
                        decoration: InputDecoration(labelText: 'Variant/Flavor/Volume'),
                        textCapitalization: TextCapitalization.words,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        textInputAction: TextInputAction.next,
                        onChanged: (value) => setState(() { productBuilder.variant = value; }),
                        validator: FormExtValidator.buildValidator([
                          FormExtValidator.maxLength(MAX_LEN, errorText: TOO_LONG),
                        ]),
                      ),
                    ],
                  )
                ];

                return GridView.count(
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                  crossAxisCount: orientation == Orientation.portrait? 1 : 2,
                  childAspectRatio: 1.20,
                  children: children,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
