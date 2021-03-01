import 'package:logger/logger.dart';

class SimpleLogPrinter extends LogPrinter {
  final String className;
  static const LEVEL_TEXT = {
    Level.verbose: '[verbose]',
    Level.debug: '[debug]',
    Level.info: '[info]',
    Level.warning: '[warning]',
    Level.error: '[error]',
    Level.wtf: '[wtf]',
  };

  SimpleLogPrinter(this.className);

  @override
  void log(LogEvent event) {
    var color = PrettyPrinter.levelColors[event.level];
    var text = LEVEL_TEXT[event.level];

    println('$color$text $className - ${event.message}');
  }
}
