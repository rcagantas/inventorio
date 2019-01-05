import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/widgets/item_add_page.dart';
import 'package:inventorio/widgets/item_card.dart';
import 'package:inventorio/widgets/scan_page.dart';
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
          if (!snap.hasData || snap.data.length == 0) return _buildWelcome();
          return ListView.builder(
            itemCount: snap.data?.length ?? 0,
            itemBuilder: (context, index) => ItemCard(snap.data[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          String code = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => ScanPage()));
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => ItemAddPage(InventoryItem(uuid: RepositoryBloc.generateUuid(), code: code)))
          );
        },
        icon: Icon(FontAwesomeIcons.barcode),
        label: Text('Scan Barcode')
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
