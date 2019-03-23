import 'package:flutter/material.dart';
import 'package:inventorio/data/definitions.dart';
import 'package:inventorio/widgets/item_card.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/inventory_bloc.dart';
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

class WidgetFactory {
  static var titleStyle = TextStyle(fontSize: 30.0, fontWeight: FontWeight.bold);

  static Widget titleCard() {
    return ListTile(
      contentPadding: EdgeInsets.all(20.0),
      title: Text('Inventorio', style: titleStyle, textAlign: TextAlign.center,),
      subtitle: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snap) {
          var version = snap.hasData? 'version ${snap.data.version} build ${snap.data.buildNumber}': '';
          return Text('$version', textAlign: TextAlign.center,);
        },
      ),
    );
  }

  static Widget buildWelcome(List<Widget> header, List<Widget> tail) {
    List<Widget> children = <Widget>[
      Container(height: 100.0,),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: header,
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          titleCard(),
          Image.asset('resources/icons/icon_transparent.png', width: 150.0, height: 150.0, key: ObjectKey('inventorio_logo'),),
        ],
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: tail,
      )
    ];

    return ListView(
      key: ObjectKey('inventorio_welcome'),
      children: children,
    );
  }

  static void launchUrl(String url) async {
    if (await launcher.canLaunch(url)) {
      await launcher.launch(url);
    } else {
      print('Cannot launch $url');
    }
  }

  static Widget link(BuildContext context, String text, String url) {
    var width = MediaQuery.of(context).size.width * .70;
    var urlStyle = TextStyle(fontSize: 16.0, color: Colors.blueAccent);

    return SizedBox(
      width: width,
      height: 25.0,
      child: FlatButton(
        padding: EdgeInsets.zero,
        child: Text(text, textAlign: TextAlign.center, style: urlStyle,),
        onPressed: () => launchUrl(url),
      ),
    );
  }


  static Widget _buildWelcomeInstructions(BuildContext context) {
    List<Widget> header = <Widget>[];
    List<Widget> tail = <Widget>[
      ListTile(title: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('Welcome To Inventorio', textAlign: TextAlign.center,),
      ),),
      ListTile(title: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('Scanned items and expiration dates will appear here.', textAlign: TextAlign.center,),
      ),),
      ListTile(title: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('Scan new items by tapping the button below.', textAlign: TextAlign.center,),
      ),),

    ];
    return buildWelcome(header, tail);
  }

  static Widget buildList(BuildContext context, {bool showInstructions = true}) {
    var _bloc = Injector.getInjector().get<InventoryBloc>();
    return StreamBuilder<List<InventoryItem>>(
      stream: _bloc.selectedStream,
      builder: (context, snap) {
        if (!snap.hasData || snap.data.length == 0) {
          return _buildWelcomeInstructions(context);
        }

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
}