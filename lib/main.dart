import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Inventorio', // Doesn't seem to do anything - RC
      theme: new ThemeData(primarySwatch: Colors.blue,),
      home: new MyHomePage(title: 'Inventorio'), // This sets the header - RC
    );
  }
}

class MyHomePage extends StatefulWidget {
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".
  final String title;
  MyHomePage({Key key, this.title}) : super(key: key);

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class InventoryItem {
  final uuid, label, expirationDate;
  InventoryItem(this.uuid, this.label, this.expirationDate);
}

class _MyHomePageState extends State<MyHomePage> {
  final uuidGenerator = new Uuid();
  final List<InventoryItem> inventoryItems = new List();

  @override
  Widget build(BuildContext context) {
    void _addItem() {
      setState(() {
        inventoryItems.add(new InventoryItem(uuidGenerator.v4(), "Optional Label", "Expiration Date"));
      });
    }

    // This method is rerun every time setState is called.
    return new Scaffold(
      appBar: new AppBar(title: new Text(widget.title),),
      body: new ListView.builder(
        itemCount: inventoryItems.length,
        itemBuilder: (BuildContext context, int index) => new ListTile(
          leading: new CircleAvatar(),
          title: new Text(inventoryItems[index].label),
          subtitle: new Text(inventoryItems[index].uuid),
          trailing: new Text(inventoryItems[index].expirationDate),
        ),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: _addItem,
        tooltip: 'Add new inventory ite,',
        child: new Icon(Icons.add),
      ),
    );
  }
}
