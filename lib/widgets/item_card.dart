import 'package:flutter/material.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/inventory_bloc.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:quiver/strings.dart' as qString;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventorio/inventory_repository.dart';

class ProductImage extends StatelessWidget {
  final _repo = Injector.getInjector().get<InventoryRepository>();
  final InventoryItemEx item;
  ProductImage(this.item);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      key: ObjectKey(item.uuid+'_image'),
      stream: _repo.getProductObservable(item.inventoryId, item.code),
      builder: (context, AsyncSnapshot<Product> snapshot) {
        if (snapshot.hasData && qString.isNotEmpty(snapshot.data.imageUrl)) {
          return CachedNetworkImage(
            imageUrl: snapshot.data.imageUrl ?? '', fit: BoxFit.cover,
            placeholder: Center(child: Icon(Icons.camera_enhance, color: Colors.grey)),
            errorWidget: Center(child: Icon(Icons.error_outline, color: Colors.grey)),
          );
        }
        return Center(child: Icon(Icons.camera_alt, color: Colors.grey));
      },
    );
  }
}


class ProductLabel extends StatelessWidget {
  final _repo = Injector.getInjector().get<InventoryRepository>();
  final InventoryItemEx item;
  ProductLabel(this.item);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      key: ObjectKey(item.uuid+'_label'),
      initialData: Product(brand: item.code, variant: item.uuid),
      stream: _repo.getProductObservable(item.inventoryId, item.code),
      builder: (context, AsyncSnapshot<Product> snapshot) {
        if (snapshot.hasData) {
          return _buildLabel(snapshot.data);
        }
        return Container();
      },
    );
  }

  Widget _buildLabel(Product product) {
    var style =  TextStyle(inherit: true, fontWeight: FontWeight.bold);
    List<Text> labels = [
      Text('${product?.brand ?? ''}',   textAlign: TextAlign.left,),
      Text('${product?.name ?? ''}',    textAlign: TextAlign.left, style: style,),
      Text('${product?.variant ?? ''}', textAlign: TextAlign.left,),
    ];
    labels.retainWhere((text) => text.data.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: labels,
    );
  }
}

class ItemExpiry extends StatelessWidget {
  final InventoryItemEx item;
  ItemExpiry(this.item);

  @override
  Widget build(BuildContext context) {
    var style =  TextStyle(inherit: true, fontFamily: 'Raleway',fontWeight: FontWeight.bold);
//    return ClipRect(
//      child: Align(
//        alignment: Alignment.bottomCenter,
//        //heightFactor: 0.8,
//        child:
//      ),
//    );
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        ClipRect(
          child: Align(
            alignment: Alignment.bottomLeft,
            heightFactor: 0.8,
            child: Container(color: Colors.red,),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text('${item.year}',              style: style,),
            Text('${item.month} ${item.day}', style: style,),
          ],
        ),
      ],
    );
  }
}


class ItemCard extends StatelessWidget {
  final InventoryItemEx item;
  ItemCard(this.item);

  @override
  Widget build(BuildContext context) {
    double textScaleFactor = MediaQuery.of(context).textScaleFactor;

    return Container(
      height: 130.0 * textScaleFactor,
      child: Card(
        child: Row(
          children: <Widget>[
            Expanded(flex: 25, child: ProductImage(item),),
            Spacer(flex: 5),
            Expanded(flex: 70, child: ProductLabel(item),),
            //Expanded(flex: 3, child: ItemExpiry(item),)
          ],
        ),
      ),
    );
  }
}
