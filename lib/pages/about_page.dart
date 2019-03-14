import 'package:flutter/material.dart';
import 'package:inventorio/widgets/widget_factory.dart';

class AboutPage extends StatelessWidget {
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
    var yearNow = DateTime.now().year.toString();
    var startYear = '2019';
    var copyRightRange = yearNow;

    copyRightRange = startYear == yearNow ? yearNow : '$startYear - $yearNow';

    List<Widget> textList = <Widget>[
      WidgetFactory.link(context, '• Framework by Flutter', 'https://flutter.dev'),
      WidgetFactory.link(context, '• Written in Dart', 'https://www.dartlang.org'),
      _nonLink('• Icon by Sophie Liverman'),
    ];

    List<Widget> header = <Widget>[

    ];

    List<Widget> tail = <Widget>[
      ListTile(
        title: Text('© $copyRightRange Roel Cagantas', textAlign: TextAlign.center,),
        subtitle: Text('All rights reserved.', textAlign: TextAlign.center,),
      ),
      WidgetFactory.link(context, 'Privacy Policy', 'https://rcagantas.github.io/inventorio/inventorio_privacy_policy.html'),
      SizedBox(height: 35.0,),
      Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: textList
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text('About'),),
      body: WidgetFactory.buildWelcome(header, tail),
    );
  }
}
