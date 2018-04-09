import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:barcode_scan/barcode_scan.dart';

void main() => runApp(new StateManagerWidget(new MyApp()));

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        title: 'Inventorio', // Doesn't seem to do anything - RC
        theme: new ThemeData(primarySwatch: Colors.blue,),
        home: new ListingsPage(),
        routes: <String, WidgetBuilder> {
          '/listings': (context) => new ListingsPage(),
          '/add/inventoryItem': (context) => new AddNewInventoryItemPage(),
        }
    );
  }
}

class InventoryItem {
  static Uuid uuidGen = new Uuid();
  String uuid = uuidGen.v4();
  String code;
  DateTime expiryDate;
  InventoryItem() { print('adding $uuid'); }
}

class AppState {
  List<InventoryItem> inventoryItems = new List();
}

/// the only purpose is to propagate changes to entire tree
class AppStateWidget extends InheritedWidget {
  final StateManager stateManager;
  AppStateWidget({this.stateManager, child}): super(child: child);
  @override bool updateShouldNotify(InheritedWidget oldWidget) => true;
}

/// the only purpose is to contain the entire widget tree
class StateManagerWidget extends StatefulWidget {
  final Widget child;
  StateManagerWidget(this.child);
  @override State<StateManagerWidget> createState() => new StateManager();
}

/// holds and manages the app state
class StateManager extends State<StateManagerWidget> {
  final AppState appState = new AppState();
  InventoryItem stagingItem = new InventoryItem();

  void addItem(InventoryItem item) {
    setState(() { appState.inventoryItems.add(item); });
  }

  void removeItemAtIndex(int index) {
    setState(() { appState.inventoryItems.removeAt(index); });
  }

  Future<String> scanBarcode() async {
    String code = await BarcodeScanner.scan();
    stagingItem.code = code;
    return code;
  }

  static StateManager of(BuildContext context) {
    return (context.inheritFromWidgetOfExactType(AppStateWidget) as AppStateWidget).stateManager;
  }

  @override Widget build(BuildContext context) => new AppStateWidget(stateManager: this, child: widget.child);
}

class ListingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final StateManager state = StateManager.of(context);

    return new Scaffold(
      appBar: new AppBar(title: new Text('Inventorio'),),
      body: ListView.builder(
        itemCount: state.appState.inventoryItems.length,
        itemBuilder: (BuildContext context, int index) =>
          new Dismissible(
            key: new ObjectKey(state.appState.inventoryItems[index].uuid),
            child: new ListTile(title: new Text(state.appState.inventoryItems[index].uuid)),
            onDismissed: (direction) { state.removeItemAtIndex(index); },
          ),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () async {
          Navigator.of(context).pushNamed('/add/inventoryItem');
        },
        child: new Icon(Icons.add_a_photo),
      ),
    );
  }
}

class AddNewInventoryItemPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final StateManager state = StateManager.of(context);
    return new Scaffold(
      appBar: new AppBar(title: new Text('Add New Inventory Item')),
      body: new FlatButton(
        onPressed: () { state.scanBarcode(); },
        child: new Container(
          decoration: new BoxDecoration(
            image: new DecorationImage(
              image: AssetImage('resources/images/barcode.png'),
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
      ),
    );
  }
}
