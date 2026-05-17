import 'package:intl/intl.dart';

abstract final class DateFormatter {
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm');
  static final _date = DateFormat('dd/MM/yyyy');

  static String formatDateTime(DateTime dt) => _dateTime.format(dt);
  static String formatDate(DateTime dt) => _date.format(dt);
}
