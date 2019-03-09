import 'package:flutter/material.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:inventorio/bloc/repository_bloc.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/widgets/dialog_factory.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';

class InventoryDetailsPage extends StatefulWidget {
  InventoryDetailsPage(this.inventoryDetails);
  final InventoryDetails inventoryDetails;
  @override State<InventoryDetailsPage> createState() => _InventoryDetailsState();
}

class _InventoryDetailsState extends State<InventoryDetailsPage> {
  InventoryDetails staging;
  TextEditingController _name;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _bloc = Injector.getInjector().get<InventoryBloc>();

  @override
  void initState() {
    staging = widget.inventoryDetails == null
        ? InventoryDetails(uuid: RepositoryBloc.generateUuid())
        : widget.inventoryDetails;
    _name = TextEditingController(text: staging.name);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inventory Settings')),
      body: Container(
          padding: EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: <Widget>[
                TextFormField(
                  maxLength: 60,
                  controller: _name,
                  keyboardType: TextInputType.text,
                  decoration: new InputDecoration(
                    labelText: 'New Inventory Name',
                    suffixIcon: IconButton(
                      icon: Icon(Icons.cancel, size: 18.0),
                      onPressed: () { _name.clear(); }
                    ),
                  ),
                ),
                Divider(),
                ListTile(title: Text('Share this inventory by scanning the image below.', textAlign: TextAlign.center,)),
                Center(
                  child: QrImage(
                    data: staging.uuid,
                    size: 250.0,
                  ),
                ),
                Text(staging.uuid, textAlign: TextAlign.center,),
                widget.inventoryDetails == null
                    ? Container(width: 0.0, height: 0.0,)
                    : ListTile(
                  title: RaisedButton(
                    child: Text('Unsubscribe from inventory'),
                    onPressed: () async {
                      var confirmed = await DialogFactory.sureDialog(context,
                          'Unsubscribing would remove this inventory and all its items from your list', 'Unsubscribe', 'Cancel');
                      if (confirmed) {
                        _bloc.actionSink(Action(Act.UnsubscribeInventory, staging));
                      }
                      Navigator.pop(context, null);
                    }
                  ),
                ),
              ],
            ),
          )
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.input),
        onPressed: () {
          staging.name = _name.text;
          _bloc.actionSink(Action(Act.UpdateInventory, staging));
          Navigator.pop(context, staging);
        },
      ),
    );
  }
}