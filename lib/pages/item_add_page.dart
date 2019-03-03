import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/widgets/item_card.dart';
import 'package:inventorio/pages/product_page.dart';

class ItemAddPage extends StatefulWidget {
  final InventoryItem item;
  ItemAddPage(this.item);
  @override _ItemAddPageState createState() => _ItemAddPageState();
}

class _ItemAddPageState extends State<ItemAddPage> {
  final _repo = Injector.getInjector().get<RepositoryBloc>();
  final _bloc = Injector.getInjector().get<InventoryBloc>();

  InventoryItem stagingItem;

  @override
  void initState() {
    stagingItem = InventoryItem.fromJson(widget.item.toJson())
      ..inventoryId = widget.item.inventoryId;
    super.initState();
  }

  DateTime _initialDateTime() {
    return widget.item.expiryDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Set Expiry Date'),),
      body: ListView(
        children: <Widget>[
          ListTile(title: Text('${widget.item.code}', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Raleway'),),),
          FlatButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(widget.item)));
            },
            child: Container(
              height: 150.0,
              child: Card(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    ProductImage(widget.item, height: 150.0, width: 150.0,),
                    ProductLabel(widget.item, width: 200.0,),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 200.0,
            child: Card(
              child: DefaultTextStyle(
                style: TextStyle(
                  color: CupertinoColors.black,
                  fontSize: 22.0,
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _initialDateTime(),
                  onDateTimeChanged: (dateTime) async {
                    stagingItem.dateAdded = DateTime.now().toIso8601String();
                    stagingItem.expiry = _repo.setExpiryString(dateTime);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          Product product = await _repo.getProductFuture(widget.item.inventoryId, widget.item.code);
          if (product.isInitial) {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => ProductPage(widget.item)));
          }
          Navigator.pop(context);
          Future.delayed(Duration(milliseconds: 30), () {
            _bloc.actionSink(Action(Act.AddUpdateItem, stagingItem));
          });
        }
      ),
    );
  }
}
