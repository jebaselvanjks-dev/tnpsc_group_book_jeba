import 'package:intl/intl.dart';

class AppDate {
  static DateTime getISTNow() {
    return DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  }

  static String getTodayString() {
    return DateFormat('yyyy-MM-dd', 'en_US').format(getISTNow());
  }
  
  static String format(DateTime date) {
    return DateFormat('yyyy-MM-dd', 'en_US').format(date);
  }
  
  static DateTime parse(String dateStr) {
    return DateFormat('yyyy-MM-dd', 'en_US').parse(dateStr);
  }
}
