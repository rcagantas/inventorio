import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/inventory_bloc.dart';
import 'package:inventorio/inventory_repository.dart';
import 'package:inventorio/widgets/item_card.dart';
import 'package:inventorio/data/definitions.dart';

class ListingsPage extends StatelessWidget {
  final _inventoryBloc = Injector.getInjector().get<InventoryBloc>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder(
          stream: _inventoryBloc.currentInventory,
          builder: (context, AsyncSnapshot<InventoryDetails> snapshot) {
            return snapshot.hasData
                ? Text('${snapshot.data.name}')
                : Text('Current Inventory');
          }
        )
      ),
      body: StreamBuilder(
        stream: _inventoryBloc.allItems,
        builder: (context, AsyncSnapshot<List<InventoryItemEx>> snapshot) {
          return !snapshot.hasData
              ? _buildWelcome()
              : ListView.builder(
                  itemCount: snapshot.data.length,
                  itemBuilder: (context, index) => ItemCard(snapshot.data[index]),
                );
        }
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async { _inventoryBloc.newEntry(InventoryEntry()); },
        icon: Icon(Icons.add_a_photo),
        label: Text('Scan Barcode')
      ),
      //floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.add_a_photo, color: Colors.grey.shade400, size: 150.0,),
          ListTile(title: Text('Welcome to Inventorio', textAlign: TextAlign.center,)),
          ListTile(title: Text('Scanned items and expiration dates will appear here. ', textAlign: TextAlign.center,)),
          ListTile(title: Text('Scan new items by clicking the button below.', textAlign: TextAlign.center,)),
        ],
      ),
    );
  }
}
