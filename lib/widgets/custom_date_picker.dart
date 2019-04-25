import 'package:flutter/material.dart';

class CustomDatePicker extends StatefulWidget {
  final DateTime minimumDate;
  final dynamic mode;
  final ValueChanged<DateTime> onDateTimeChanged;
  CustomDatePicker(this.minimumDate, this.mode, this.onDateTimeChanged);

  @override
  _CustomDatePickerState createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<CustomDatePicker> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[

      ],
    );
  }
}
