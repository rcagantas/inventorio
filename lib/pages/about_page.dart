import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:package_info/package_info.dart';

class AboutPage extends StatelessWidget {
  void _launchUrl(String url) async {
    if (await launcher.canLaunch(url)) {
      await launcher.launch(url);
    } else {
      print('Cannot launch $url');
    }
  }

  Widget _link(BuildContext context, String text, String url) {
    var width = MediaQuery.of(context).size.width * .70;
    var urlStyle = TextStyle(fontSize: 16.0, color: Colors.blueAccent);

    return SizedBox(
      width: width,
      height: 25.0,
      child: FlatButton(
        padding: EdgeInsets.zero,
        child: Text(text, textAlign: TextAlign.center, style: urlStyle,),
        onPressed: () => _launchUrl(url),
      ),
    );
  }

  Widget _nonLink(String text) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Text(text,
        style: TextStyle(fontSize: 16.0),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var titleStyle = TextStyle(fontSize: 30.0, fontWeight: FontWeight.bold);
    var yearNow = DateTime.now().year.toString();
    var startYear = '2019';
    var copyRightRange = yearNow;

    copyRightRange = startYear == yearNow ? yearNow : '$startYear - $yearNow';

    List<Widget> textList = <Widget>[
      _link(context, '• Framework by Flutter', 'https://flutter.dev'),
      _link(context, '• Written in Dart', 'https://www.dartlang.org'),
      _nonLink('• Icon by Sophie Liverman'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('About'),),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            ListTile(
              title: Text('Inventorio', style: titleStyle, textAlign: TextAlign.center,),
              subtitle: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) {
                  var version = snap.hasData? 'version ${snap.data.version} build ${snap.data.buildNumber}': '';
                  return Text('$version', textAlign: TextAlign.center,);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset('resources/icons/icon_transparent.png', width: 150.0, height: 150.0,),
            ),
            ListTile(
              title: Text('© $copyRightRange Roel Cagantas', textAlign: TextAlign.center,),
              subtitle: Text('All rights reserved.', textAlign: TextAlign.center,),
            ),
            _link(context, 'Privacy Policy', 'https://rcagantas.github.io/inventorio/inventorio_privacy_policy.html'),
            SizedBox(height: 35.0,),
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: textList
            ),
          ],
        ),
      ),
    );
  }
}
