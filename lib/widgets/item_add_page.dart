import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/widgets/item_card.dart';

class ItemAddPage extends StatefulWidget {
  final InventoryItem item;
  ItemAddPage(this.item);
  @override _ItemAddPageState createState() => _ItemAddPageState();
}

class _ItemAddPageState extends State<ItemAddPage> {

  DateTime _initialDateTime() {
    return widget.item.expiryDate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Set Expiry Date'),),
      body: ListView(
        children: <Widget>[
          ListTile(title: Text('Product code: ${widget.item.code}', textAlign: TextAlign.center,),),
          Container(
            height: 150.0,
            child: Card(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Expanded(flex: 1, child: ProductImage(widget.item)),
                  Expanded(flex: 2, child: ProductLabel(widget.item))
                ],
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
                  onDateTimeChanged: (dateTime) {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
