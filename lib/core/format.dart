import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.00');
final _date = DateFormat('d MMM yyyy');
final _shortDate = DateFormat('EEE d MMM');
final _time = DateFormat('HH:mm');
final _month = DateFormat('MMMM yyyy');

String money(num? value) => value == null ? '—' : 'P${_money.format(value)}';
String formatDate(DateTime? d) => d == null ? '—' : _date.format(d);
String shortDate(DateTime? d) => d == null ? '—' : _shortDate.format(d);
String formatTime(DateTime? d) => d == null ? '—' : _time.format(d);
String dateTime(DateTime? d) => d == null ? '—' : '${_shortDate.format(d)}, ${_time.format(d)}';
String monthName(DateTime d) => _month.format(d);
String yearMonth(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
