import 'package:intl/intl.dart';

final Map<String, NumberFormat> _intFormatCache = <String, NumberFormat>{};
final Map<String, NumberFormat> _doubleFormatCache = <String, NumberFormat>{};

String intFormat(int value, String locale) {
  final f = _intFormatCache.putIfAbsent(
    locale,
    () => NumberFormat("#,###", locale),
  );
  return f.format(value);
}

String doubleFormat(double value, String locale) {
  final f = _doubleFormatCache.putIfAbsent(
    locale,
    () => NumberFormat("#.##", locale),
  );
  return f.format(value);
}
