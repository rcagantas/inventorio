import 'package:flutter/material.dart';
import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:inventorio/bloc/logger_bloc.dart';
import 'package:logging/logging.dart';

class LoggingPage extends StatelessWidget {
  final _logger = Injector.getInjector().get<LoggerBloc>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Logs'),),
      body: StreamBuilder<List<LogRecord>>(
        initialData: [],
        stream: _logger.auditStream,
        builder: (context, snap) {
          double textScaleFactor = MediaQuery.of(context).textScaleFactor;
          if (!snap.hasData) return Container();
          return ListView.builder(
            itemCount: snap.data.length,
            itemExtent: 60.0 * textScaleFactor,
            itemBuilder: (context, index) {
              TextStyle style = new TextStyle(fontSize: 11.0);
              String date = snap.data[index].time.toIso8601String().substring(0, 10);
              String time = snap.data[index].time.toIso8601String().substring(11, 19);
              String message = snap.data[index].message;
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
        },
      ),
    );
  }
}
