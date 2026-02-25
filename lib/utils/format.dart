import 'package:intl/intl.dart';

String tl(num n) => NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(n);
String dt(DateTime d) => DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(d);
