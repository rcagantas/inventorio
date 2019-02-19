import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

class LoggerBloc {
  final List<LogRecord> _audit = [];
  final _auditStream = BehaviorSubject<List<LogRecord>>();
  Observable<List<LogRecord>> get auditStream => _auditStream.stream;

  void addMessage(LogRecord record) {
    print('${record.time}: ${record.message}');
    _audit.insert(0, record);
    if (_audit.length > 1000) _audit.removeRange(1000, _audit.length);
    _auditStream.sink.add(_audit);
  }

  void dispose() { _auditStream.close(); }
}