import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/inventory_bloc.dart';

class ListingsPage extends StatelessWidget {
  final InventoryBloc _inventoryBloc = Injector.getInjector().get<InventoryBloc>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Current Inventory'),),
      body: StreamBuilder(
          stream: _inventoryBloc.allItems,
          builder: (context, AsyncSnapshot<List<InventoryItemEx>> snapshot) {
            if (snapshot.hasData) {
              return ListView.builder(itemBuilder: (context, index) {
                return Card(
                  child: ListTile(title: Text('${snapshot.data[index].inventoryId}'),),
                );
              });
            }
            return Center(
              child: Text('No data'),
            );
          }
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          _inventoryBloc.newEntry(InventoryEntry());
        },
        icon: Icon(Icons.add_a_photo),
        label: Text('Scan Barcode')
      ),
      //floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
