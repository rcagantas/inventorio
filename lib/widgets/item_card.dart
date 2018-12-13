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
        return snapshot.hasData ? _buildLabel(snapshot.data) : Container();
      },
    );
  }

  Widget _buildLabel(Product product) {
    var style =  TextStyle(inherit: true, fontWeight: FontWeight.bold);
    var align = TextAlign.center;
    List<Text> labels = [
      Text('${product?.brand ?? ''}',   textAlign: align,),
      Text('${product?.name ?? ''}',    textAlign: align, style: style,),
      Text('${product?.variant ?? ''}', textAlign: align,),
    ];
    labels.retainWhere((text) => text.data.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: labels,
      ),
    );
  }
}

class ItemExpiry extends StatelessWidget {
  final InventoryItemEx item;
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
  final InventoryItemEx item;
  ItemCard(this.item);

  Color _expiryColorScale(int days) {
    if (days < 30) return Colors.redAccent;
    else if (days < 90) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    double textScaleFactor = MediaQuery.of(context).textScaleFactor;

    return Container(
      height: 125.0 * textScaleFactor,
      child: Card(
        child: Row(
          children: <Widget>[
            Expanded(flex: 3, child: ProductImage(item),),
            Expanded(flex: 7, child: ProductLabel(item),),
            Expanded(flex: 3, child: ItemExpiry(item),),
            ConstrainedBox(
              constraints: BoxConstraints.tight(Size(3.0, double.infinity)),
              child: Container(color: _expiryColorScale(item.daysFromToday),),
            )
          ],
        ),
      ),
    );
  }
}
