
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/models/product.dart';
import 'package:inventorio/core/providers/action_sink_provider.dart';
import 'package:inventorio/core/providers/product_provider.dart';
import 'package:inventorio/view/product/edit/form_validator.dart';
import 'package:inventorio/view/product/edit/image_form_field.dart';

class EditProductPage extends ConsumerStatefulWidget {
  const EditProductPage({Key? key}) : super(key: key);

  @override
  ConsumerState<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends ConsumerState<EditProductPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameFocus = FocusNode();
  final _variantFocus = FocusNode();

  static const MAX_LEN = 60;
  static const TOO_LONG = 'Text is too long';
  static const REQUIRED = 'Field is required';

  bool validFab = false;
  File? imageFile;
  late CompressionStatus compressionStatus;
  late ProductBuilder productBuilder;

  @override
  void initState() {
    compressionStatus = CompressionStatus.NOT_STARTED;
    productBuilder = ProductBuilder();
    super.initState();
  }

  void checkValid() {
    bool validForm = _formKey.currentState?.validate() ?? false;
    setState(() {
      validFab = validForm && compressionStatus != CompressionStatus.IN_PROGRESS;
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _variantFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = ModalRoute.of(context)?.settings.arguments as Item;
    ref.watch(productStreamProvider(item)).whenData((product) {
      if (productBuilder.code == null) {
        setState(() {
          final blankProduct = new Product(code: item.code, name: null, brand: null, variant: null, imageUrl: null);
          productBuilder = product.name == null
            ? ProductBuilder.fromProduct(blankProduct)
            : ProductBuilder.fromProduct(product);
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text('Edit Product Details')),
      floatingActionButton: Visibility(
        visible: validFab,
        child: FloatingActionButton(
          onPressed: () {
            final product = productBuilder.build();
            ref.read(actionSinkProvider).updateProduct(item.inventoryId!, product, imageFile);
            ref.read(productProvider(item).notifier).setLatest(product);
            Navigator.pop(context, product);
          },
          child: Icon(Icons.save_alt),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: GridView.count(
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            crossAxisCount: 1,
            childAspectRatio: 1.20,
            children: [
              ImageFormField(
                item: item,
                onChanged: (status, img) {
                  setState(() {
                    this.compressionStatus = status;
                    this.imageFile = img;
                  });
                  if (img != null) {
                    ref.read(productImageFilePathProvider(item.code!).notifier).state = img.path;
                  }
                  checkValid();
                },
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${item.code}',
                    style: Theme.of(context).textTheme.caption,
                    textAlign: TextAlign.center,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Brand'),
                    initialValue: productBuilder.brand,
                    textCapitalization: TextCapitalization.words,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (value) => FocusScope.of(context).requestFocus(_nameFocus),
                    validator: FormValidator.buildValidator([
                      FormValidator.maxLength(MAX_LEN, errorText: TOO_LONG),
                    ]),
                    onChanged: (v) {
                      setState(() => productBuilder.brand = v);
                      checkValid();
                    },
                  ),
                  TextFormField(
                    focusNode: _nameFocus,
                    decoration: InputDecoration(labelText: 'Product'),
                    initialValue: productBuilder.name,
                    textCapitalization: TextCapitalization.words,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (value) => FocusScope.of(context).requestFocus(_variantFocus),
                    validator: FormValidator.buildValidator([
                      FormValidator.required(errorText: REQUIRED),
                      FormValidator.maxLength(MAX_LEN, errorText: TOO_LONG),
                    ]),
                    onChanged: (v) {
                      setState(() => productBuilder.name = v);
                      checkValid();
                    },
                  ),
                  TextFormField(
                    focusNode: _variantFocus,
                    decoration: InputDecoration(labelText: 'Variant/Flavor/Volume'),
                    initialValue: productBuilder.variant,
                    textCapitalization: TextCapitalization.words,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    textInputAction: TextInputAction.done,
                    validator: FormValidator.buildValidator([
                      FormValidator.maxLength(MAX_LEN, errorText: TOO_LONG),
                    ]),
                    onChanged: (v) {
                      setState(() => productBuilder.variant = v);
                      checkValid();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      )
    );
  }
}
