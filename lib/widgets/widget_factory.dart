import 'package:flutter/material.dart';
import 'package:inventorio/data/definitions.dart';
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

  static Widget buildWelcome() {
    var welcomeStyle = TextStyle(fontFamily: 'Montserrat', fontSize: 20.0);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset('resources/icons/icon_transparent.png', width: 150.0, height: 150.0,),
          ),
          Text('Welcome to Inventorio', textAlign: TextAlign.center, style: welcomeStyle,),
          Text('Scanned items and expiration dates will appear here.', textAlign: TextAlign.center, style: welcomeStyle,),
          Text('Scan new items by clicking the button below.', textAlign: TextAlign.center, style: welcomeStyle,),
        ],
      ),
    );
  }

  static Widget imageLogo(BuildContext context) {
    return Container(
      width: 200.0,
      height: 200.0,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        shape: BoxShape.circle,
        image: new DecorationImage(
          fit: BoxFit.fill,
          image: AssetImage('resources/icons/icon_transparent.png')
        )
      ),
    );
  }
}