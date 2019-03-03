import 'dart:io';

import 'package:flutter/material.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/pages/item_add_page.dart';
import 'package:inventorio/pages/product_page.dart';
import 'package:quiver/strings.dart' as qString;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:inventorio/bloc/repository_bloc.dart';

class ProductImage extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  final InventoryItem item;
  final double width;
  final double height;
  final File stagingImage;
  ProductImage(this.item, {this.width = 100.0, this.height = 100.0, this.stagingImage});

  Widget _heroChildBuilder(AsyncSnapshot<Product> snap) {
    double pWidth = width / 2;

    Widget widget = Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: pWidth,),);
    const BoxFit boxFit = BoxFit.cover;

    if (stagingImage != null) {
      widget = Image.file(stagingImage, fit: boxFit, width: width, height: height,);
    } else if (snap.hasData) {
      if (snap.data.imageFile != null) {
        widget = Image.file(snap.data.imageFile, fit: boxFit, width: width, height: height,);
      } else if (qString.isNotEmpty(snap.data.imageUrl)) {
        widget = CachedNetworkImage(
          width: width,
          height: height,
          imageUrl: snap.data.imageUrl,
          fit: boxFit,
          placeholder: (context, url) => Center(child: Icon(Icons.camera_enhance, color: Colors.grey, size: pWidth,)),
          errorWidget: (context, url, error) => Center(child: Icon(Icons.error_outline, color: Colors.grey, size: pWidth)),
        );
      }
    }

    return SizedBox(child: widget, width: width, height: height,);
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: item.heroCode,
      child: StreamBuilder<Product>(
        key: ObjectKey(item.uuid +'_image'),
        initialData: _repo.getCachedProduct(item.inventoryId, item.code),
        stream: _repo.getProductObservable(item.inventoryId, item.code),
        builder: (context, snap) => _heroChildBuilder(snap),
      ),
    );
  }
}


class ProductLabel extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  final InventoryItem item;
  final double width;
  static const bold = TextStyle(inherit: true, fontWeight: FontWeight.bold);
  static const align = TextAlign.center;

  ProductLabel(this.item, {this.width = 0.0});

  @override
  Widget build(BuildContext context) {
    double calculatedWidth = width == 0.0? MediaQuery.of(context).size.width * 0.3: width;

    return StreamBuilder<Product>(
      key: ObjectKey('label_${item.uuid}'),
      initialData: _repo.getCachedProduct(item.inventoryId, item.code),
      stream: _repo.getProductObservable(item.inventoryId, item.code),
      builder: (context, snap) {
        return Container(
          width: calculatedWidth,
          child: snap.hasData && !snap.data.isLoading
            ? _buildLabel(snap.data)
            : Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildLabel(Product product) {
    if (product.isInitial || product == null) {
      return Text('Add New Product Information',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22.0),
      );
    }

    List<Text> textLabels = [];
    if (qString.isNotEmpty(product?.brand)) {
      textLabels.add(Text('${product.brand}',
        softWrap: true, overflow: TextOverflow.fade, textAlign: align,
        key: ObjectKey('product_brand_${item.uuid}'),),);
    }

    if (qString.isNotEmpty(product?.name)) {
      textLabels.add(Text('${product?.name}',
        softWrap: true, overflow: TextOverflow.fade, textAlign: align, style: bold,
        key: ObjectKey('product_name_${item.uuid}'),),);
    }

    if (qString.isNotEmpty(product?.variant)) {
      textLabels.add(Text('${product?.variant}',
        softWrap: true, overflow: TextOverflow.fade, textAlign: align,
        key: ObjectKey('product_variant_${item.uuid}'),),);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: textLabels,
    );
  }
}

class ItemExpiry extends StatelessWidget {
  final InventoryItem item;
  final double width;
  static const style = TextStyle(inherit: true, fontFamily: 'Raleway', fontWeight: FontWeight.bold);
  static const align = TextAlign.center;

  ItemExpiry(this.item, {this.width});

  Color _expiryColorScale(int days) {
    if (days < 30) return Colors.redAccent;
    else if (days < 90) return Colors.yellow;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ObjectKey('expiry_${item.uuid}'),
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text('${item.year}', style: style, textAlign: align, key: ObjectKey('expiry_year_${item.uuid}'), ),
                Text('${item.month} ${item.day}', style: style, textAlign: align, key: ObjectKey('expiry_mmdd_${item.uuid}'), ),
              ],
            ),
          ),
          Container(
            key: ObjectKey('expiry_color_${item.uuid}'),
            width: 5.0,
            decoration: BoxDecoration(color: _expiryColorScale(item.daysFromToday),),
          ),
        ],
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  final InventoryItem item;
  static const double _BASE_HEIGHT = 110.0;
  static const double _MAX_SIDE_WIDTH = 90.0;

  ItemCard(this.item);

  static double _computeHeight(BuildContext context) {
    double textScaleFactor = MediaQuery.of(context).textScaleFactor;
    return _BASE_HEIGHT * textScaleFactor;
  }

  @override
  Widget build(BuildContext context) {
    var widgetHeight = _computeHeight(context);
    var width = MediaQuery.of(context).size.width;
    var sideWidth = widgetHeight > _MAX_SIDE_WIDTH? _MAX_SIDE_WIDTH: widgetHeight;

    return Container(
      key: ObjectKey('card_${item.uuid}'),
      height: widgetHeight,
      child: Slidable(
        delegate: SlidableDrawerDelegate(),
        key: ObjectKey(item.uuid),
        secondaryActions: <Widget>[
          IconSlideAction(
            caption: 'Edit Product',
            color: Colors.lightBlueAccent,
            icon: Icons.edit,
            onTap: () async {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProductPage(item)));
            }
          ),
          IconSlideAction(
            caption: 'Delete',
            color: Colors.red,
            icon: Icons.delete,
            onTap: () {
              Product productNameOfDeletedItem = _repo.getCachedProduct(item.inventoryId, item.code);
              _bloc.actionSink(Action(Act.RemoveItem, item));
              Scaffold.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed item ${productNameOfDeletedItem.name}'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () => _bloc.actionSink(Action(Act.AddUpdateItem, item)),
                  ),
                )
              );
            },
          ),
        ],
        child: FlatButton(
          key: ObjectKey('button_${item.uuid}'),
          padding: EdgeInsets.zero,
          onPressed: () async {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => ItemAddPage(item)));
          },
          child: Card(
            clipBehavior: Clip.hardEdge,
            child: Row(
              key: ObjectKey('row_${item.uuid}'),
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                ProductImage(item, width: sideWidth, height: widgetHeight,),
                ProductLabel(item, width: width * 0.50,),
                ItemExpiry(item, width: sideWidth,),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
