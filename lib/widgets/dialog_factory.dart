import 'package:flutter/material.dart';

class DialogFactory {
  static Future<bool> sureDialog(BuildContext context, String question, String yes, String no) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(question,),
          actions: <Widget>[
            yes == null ? Container():
            FlatButton(
              child: Text(yes),
              onPressed: () { Navigator.of(context).pop(true); },
            ),
            FlatButton(
              color: Theme.of(context).primaryColor,
              child: Text(no, style: TextStyle(color: Theme.of(context).scaffoldBackgroundColor,),),
              onPressed: () { Navigator.of(context).pop(false);},
            ),
          ],
        );
      }
    );
  }
}