import 'package:flutter/material.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/widgets/app_constants.dart';
import 'package:inventorio/widgets/item_card.dart';

class WidgetFactory {
  static Widget buildList(BuildContext context, Function() whenEmpty, Stream<List<InventoryItem>> stream) {
    return StreamBuilder<List<InventoryItem>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData || snap.data.length == 0) return whenEmpty();
        return ListView.builder(
          padding: EdgeInsets.zero,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          itemCount: snap.data?.length ?? 0,
          itemBuilder: (context, index) => ItemCard(snap.data[index]),
        );
      },
    );
  }

  static Widget _welcomeItem(String text) {
    return ListTile(title: Text(text, textAlign: TextAlign.center,),);
  }

  static Widget buildWelcome({bool withInstructions = true}) {
    List<Widget> textList = [
      ListTile(
        title: Text('Welcome to Inventorio',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0),
        ),
      ),
    ];
    if (withInstructions) {
      textList.addAll([
        _welcomeItem('Scanned items and expiration dates will appear here.'),
        _welcomeItem('Scan new items by clicking the button below.'),
      ]);
    } else {
      textList.add(_welcomeItem('Maximize your inventory'));
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset('resources/icons/icon_transparent.png', width: 180.0, height: 180.0,),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(children: textList),
          ),
        ],
      ),
    );
  }


  static TextStyle styleOverride({double size, FontWeight weight}) {
    weight = weight == null? FontWeight.normal: weight;
    if (size == null) return TextStyle(fontFamily: AppConstants.APP_FONT, fontWeight: weight);
    return TextStyle(fontFamily: AppConstants.APP_FONT, fontSize: size, fontWeight: weight);
  }
}