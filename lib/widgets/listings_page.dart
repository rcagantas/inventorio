import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/widgets/item_card.dart';
import 'package:inventorio/widgets/user_drawer.dart';

class ListingsPage extends StatelessWidget {
  final _bloc = Injector.getInjector().get<InventoryBloc>();
  final _repo = Injector.getInjector().get<RepositoryBloc>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<UserAccount>(
          stream: _repo.userUpdateStream,
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return Text('Current Inventory');
            return StreamBuilder<InventoryDetails>(
              stream: _repo.getInventoryDetailObservable(userSnapshot.data.currentInventoryId),
              builder: (context, detailSnapshot) {
                return detailSnapshot.hasData
                  ? Text('${detailSnapshot.data.name}')
                  : Text('Current Inventory');
              },
            );
          },
        )
      ),
      body: StreamBuilder<List<InventoryItem>>(
        stream: _bloc.selectedStream,
        builder: (context, snap) {
          return ListView.builder(
            itemCount: snap.data?.length ?? 0,
            itemBuilder: (context, index) => ItemCard(snap.data[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {},
        icon: Icon(Icons.add_a_photo),
        label: Text('Scan Barcode')
      ),
      //floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      drawer: UserDrawer(),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Image.asset('resources/icons/icon.png', width: 150.0, height: 150.0,),
          ListTile(title: Text('Welcome to Inventorio', textAlign: TextAlign.center,)),
          ListTile(title: Text('Scanned items and expiration dates will appear here. ', textAlign: TextAlign.center,)),
          ListTile(title: Text('Scan new items by clicking the button below.', textAlign: TextAlign.center,)),
        ],
      ),
    );
  }
}
