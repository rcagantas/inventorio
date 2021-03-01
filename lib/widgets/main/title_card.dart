import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';

class TitleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var linkStyle = Theme.of(context).textTheme.bodyText1.copyWith(
      color: Colors.blue,
      fontWeight: FontWeight.bold
    );

    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('Inventorio', style: Theme.of(context).textTheme.headline3,),
          Image.asset('resources/icons/icon_transparent.png',
            width: 150.0,
            height: 150.0
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              String version = snapshot.hasData
                  ? 'version ${snapshot.data.version} build ${snapshot.data.buildNumber}'
                  : '';
              return Text('$version');
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('© 2019 - ${DateTime.now().year} '),
              FlatButton(
                padding: EdgeInsets.all(0.0),
                onPressed: () async {
                  var url = 'https://github.com/rcagantas';
                  if (await canLaunch(url)) { launch(url); }
                },
                child: Text('Roel Cagantas', style: linkStyle,),
              ),
            ],
          ),
          FlatButton(
            child: Text('Privacy Policy', style: linkStyle,),
            onPressed: () async {
              var url = 'https://rcagantas.github.io/inventorio/inventorio_privacy_policy.html';
              if (await canLaunch(url)) { launch(url); }
            },
          ),
          SizedBox(height: 50.0,)
        ],
      ),
    );
  }
}
