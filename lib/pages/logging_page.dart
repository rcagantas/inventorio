import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/logger_bloc.dart';
import 'package:logging/logging.dart';

class _LoggingPageSearchDelegate extends SearchDelegate<LogRecord> {
  final _logger = Injector.getInjector().get<LoggerBloc>();

  Widget _auditStream() {
    return StreamBuilder<List<LogRecord>>(
      initialData: [],
      stream: _logger.auditStream,
      builder: (context, snap) {
        if (!snap.hasData) return Container();
        List filtered = snap.data
          .where((record) => record.toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
        return LoggingPage.buildList(context, filtered);
      },
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: Icon(Icons.arrow_back),
      onPressed: () { close(context, null); },
    );
  }

  @override Widget buildResults(BuildContext context) { return _auditStream(); }
  @override Widget buildSuggestions(BuildContext context) { return _auditStream(); }
}

class LoggingPage extends StatelessWidget {
  final _logger = Injector.getInjector().get<LoggerBloc>();

  static Widget buildList(BuildContext context, List<LogRecord> list) {
    double textScaleFactor = MediaQuery.of(context).textScaleFactor;

    return ListView.builder(
      itemCount: list.length,
      itemExtent: 80.0 * textScaleFactor,
      itemBuilder: (context, index) {
        TextStyle style = new TextStyle(fontFamily: 'OpenSans', fontSize: 11.0);
        String date = list[index].time.toIso8601String().substring(0, 10);
        String time = list[index].time.toIso8601String().substring(11, 19);
        String message = list[index].message;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            //Expanded(child: Text('$time', style: style, textAlign: TextAlign.center,),),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text('$date', style: style,),
                  Text('$time', style: style,),
                ],
              ),
              flex: 1,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('$message', style: style),
              ),
              flex: 4,
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    SearchDelegate<LogRecord> _searchDelegate = _LoggingPageSearchDelegate();
    return Scaffold(
      appBar: AppBar(
        title: Text('Logs'),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.search),
            onPressed:() async { showSearch(context: context, delegate: _searchDelegate); }
          )
        ],
      ),
      body: StreamBuilder<List<LogRecord>>(
        initialData: [],
        stream: _logger.auditStream,
        builder: (context, snap) {
          if (!snap.hasData) return Container();
          return buildList(context, snap.data);
        },
      ),
    );
  }
}
