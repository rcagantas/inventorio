import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDatePicker extends StatefulWidget {
  final DateTime minimumDate;
  final DateTime initialDateTime;
  final dynamic mode;
  final ValueChanged<DateTime> onDateTimeChanged;
  CustomDatePicker({this.minimumDate, this.mode, this.initialDateTime, this.onDateTimeChanged});

  @override
  _CustomDatePickerState createState() => _CustomDatePickerState();
}

class _CustomDatePickerState extends State<CustomDatePicker> {
  static const double _kFontSize = 25.0;
  ScrollController _yearController, _monthController, _dayController;
  int _startingYear;
  int _yearIndex, _monthIndex, _dayIndex;
  DateTime _selectedDate;

  @override
  void initState() {
    var date = widget.initialDateTime == null ? DateTime.now() : widget.initialDateTime;
    _selectedDate = date;
    _startingYear = date.year > DateTime.now().year? DateTime.now().year : date.year;
    _yearIndex = date.year - _startingYear; _monthIndex = date.month - 1; _dayIndex = date.day - 1;
    _yearController   = FixedExtentScrollController(initialItem: _yearIndex);
    _monthController  = FixedExtentScrollController(initialItem: _monthIndex);
    _dayController    = FixedExtentScrollController(initialItem: _dayIndex);
    super.initState();
  }

  void stateListener() {
    var year = _startingYear + _yearIndex;
    var month = (_monthIndex % 12) + 1;
    var day = (_dayIndex % _getLastDay(year, month)) + 1;

    var date = DateTime(year, month, day);
    if (_selectedDate != date) {
      widget.onDateTimeChanged(date);
      _selectedDate = date;
    }
  }

  double _getHeight(BuildContext context) {
    double textScaleFactor = MediaQuery.of(context).textScaleFactor;
    return (textScaleFactor * _kFontSize) + 30.0;
  }

  List<String> _getMonths() {
    List<String> months = [];
    DateFormat format = DateFormat('MMMM');
    for (int i = 1; i <= 12; i++) {
      DateTime date = DateTime(_startingYear + _yearIndex, i, 1);
      months.add(format.format(date));
    }
    return months;
  }

  int _getLastDay(int year, int month) {
    return DateTime(year, month + 1, 1).subtract(Duration(days: 1)).day;
  }

  Widget _buildPicker(BuildContext context, {
    @required FixedExtentScrollController scrollController,
    @required List<Widget> children,
    @required Function(int) onSelectedItemChanged,
    bool looping: true,
    int flex: 1,
    double offAxisFraction: 0.0,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: EdgeInsets.zero,
        height: 200.0,
        child: CupertinoPicker(
          offAxisFraction: offAxisFraction,
          backgroundColor: Theme.of(context).primaryTextTheme.bodyText1.backgroundColor,
          itemExtent: _getHeight(context),
          scrollController: scrollController,
          children: children,
          onSelectedItemChanged: onSelectedItemChanged,
          looping: looping,
        ),
      ),
    );
  }

  Widget _buildPickerItem(BuildContext context, String string) {
    return SizedBox.expand(
      child: Center(
        child: Text('$string',
          style: TextStyle(
            fontSize: _kFontSize,
            fontFamily: Theme.of(context).primaryTextTheme.bodyText1.fontFamily
          ),
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(width: 15.0,),
        _buildPicker(
          context,
          looping: false,
          offAxisFraction: -0.8,
          scrollController: _yearController,
          children: List<Widget>.generate(100, (index) {
            var selected = index + _startingYear;
            return _buildPickerItem(context, '$selected',);
          }),
          onSelectedItemChanged: (index) {
            setState(() {
              _yearIndex = index;
              stateListener();
            }); // need to trigger for changing length of days
          },
        ),
        _buildPicker(
          context,
          flex: 2,
          scrollController: _monthController,
          children: List<Widget>.generate(12, (index) {
            return _buildPickerItem(context, '${_getMonths()[index]}');
          }),
          onSelectedItemChanged: (index) {
            setState(() {
              _monthIndex = index;
              stateListener();
            }); // need to trigger for changing length of days
          },
        ),
        _buildPicker(
          context,
          offAxisFraction: 0.8,
          scrollController: _dayController,
          children: List<Widget>.generate(_getLastDay(_startingYear + _yearIndex, _monthIndex + 1), (index) {
            var selected = index + 1;
            return _buildPickerItem(context, '$selected');
          }),
          onSelectedItemChanged: (index) {
            setState(() {
              _dayIndex = index;
              stateListener();
            });
          },
        ),
        Container(width: 15.0,),
      ],
    );
  }
}
