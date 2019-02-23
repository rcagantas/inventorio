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
  final double placeHolderSize;
  final File stagingImage;
  ProductImage(this.item, {this.placeHolderSize, this.stagingImage});

  Widget _heroChildBuilder(AsyncSnapshot<Product> snap) {
    if (snap.hasData && qString.isNotEmpty(snap.data.imageUrl)) {
      if (snap.data.imageFile != null) {
        return Image.file(snap.data.imageFile, fit: BoxFit.cover,);
      }

      return CachedNetworkImage(
        imageUrl: snap.data?.imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Center(child: Icon(Icons.camera_enhance, color: Colors.grey, size: placeHolderSize,)),
        errorWidget: (context, url, error) => Center(child: Icon(Icons.error_outline, color: Colors.grey, size: placeHolderSize)),
      );
    }

    return Center(child: Icon(Icons.camera_alt, color: Colors.grey, size: placeHolderSize,));
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: item.heroCode,
      child: stagingImage != null
        ? Image.file(stagingImage, fit: BoxFit.cover,)
        : StreamBuilder<Product>(
        key: ObjectKey(item.uuid +'_image'),
        initialData: _repo.getCachedProduct(item.inventoryId, item.code),
        stream: _repo.getProductObservable(item.inventoryId, item.code),
        builder: (context, snap) {
          return _heroChildBuilder(snap);
        },
      ),
    );
  }
}


class ProductLabel extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  final InventoryItem item;
  ProductLabel(this.item);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Product>(
      key: ObjectKey(item.uuid +'_label'),
      initialData: _repo.getCachedProduct(item.inventoryId, item.code),
      stream: _repo.getProductObservable(item.inventoryId, item.code),
      builder: (context, snap) {
        return Center(
          child: snap.hasData && snap.data.isLoading == false
            ? _buildLabel(snap.data)
            : CircularProgressIndicator(),
        );
      },
    );
  }

  Widget _buildLabel(Product product) {
    if (product.isInitial)
      return Text('Add New Product Information', textAlign: TextAlign.center, style: TextStyle(fontSize: 22.0),);

    var style =  TextStyle(inherit: true, fontWeight: FontWeight.bold);
    var align = TextAlign.center;
    List<Text> labels = [
      Text('${product?.brand ?? ''}',   textAlign: align,),
      Text('${product?.name ?? ''}',    textAlign: align, style: style,),
      Text('${product?.variant ?? ''}', textAlign: align,),
    ];
    labels.retainWhere((text) => text.data.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: labels,
      ),
    );
  }
}

class ItemExpiry extends StatelessWidget {
  final InventoryItem item;
  ItemExpiry(this.item);

  @override
  Widget build(BuildContext context) {
    var style = TextStyle(inherit: true, fontFamily: 'Raleway',fontWeight: FontWeight.bold);
    var align = TextAlign.center;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text('${item.year}', style: style, textAlign: align,),
        Text('${item.month} ${item.day}', style: style, textAlign: align,),
      ],
    );
  }
}

class ItemCard extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  final InventoryItem item;
  static const double _BASE_HEIGHT = 110.0;

  ItemCard(this.item);

  Color _expiryColorScale(int days) {
    if (days < 30) return Colors.redAccent;
    else if (days < 90) return Colors.yellow;
    return Colors.greenAccent;
  }

  static double height(BuildContext context) {
    double textScaleFactor = MediaQuery.of(context).textScaleFactor;
    return _BASE_HEIGHT * textScaleFactor;
  }

  @override
  Widget build(BuildContext context) {

    return Slidable(
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
      child: Card(
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (context) => ItemAddPage(item)));
          },
          child: Row(
            children: <Widget>[
              Expanded(flex: 1, child: ProductImage(item),),
              Expanded(flex: 3, child: ProductLabel(item),),
              Expanded(flex: 1, child: ItemExpiry(item),),
              Container(
                height: height(context), width: 5.0,
                color: _expiryColorScale(item.daysFromToday),
              ),
            ],
          ),
        ),
      )
    );
  }
}
