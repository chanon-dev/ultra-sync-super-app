import 'package:ultra_sync/core/utils/date_formatter.dart';

extension DateTimeExt on DateTime {
  String get formatted => DateFormatter.formatDateTime(this);
  String get dateOnly => DateFormatter.formatDate(this);
}
