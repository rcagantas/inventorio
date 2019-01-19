import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

class LoggerBloc {
  final List<LogRecord> _audit = [];
  final _auditStream = BehaviorSubject<List<LogRecord>>();
  Observable<List<LogRecord>> get auditStream => _auditStream.stream.debounce(Duration(milliseconds: 300));

  void addMessage(LogRecord record) {
    print('${record.time}: ${record.message}');
    _audit.add(record);
    _auditStream.sink.add(_audit);
  }

  void dispose() { _auditStream.close(); }
}