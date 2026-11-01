/// Formats a number with Indian digit grouping, e.g. 7254012 -> "72,54,012".
/// Written by hand so the project doesn't need to pull in `intl` just
/// for this one thing.
String formatInr(num value) {
  final bool isNegative = value < 0;
  final int n = value.round().abs();
  final String s = n.toString();

  String result;
  if (s.length <= 3) {
    result = s;
  } else {
    final String last3 = s.substring(s.length - 3);
    String rest = s.substring(0, s.length - 3);
    final List<String> parts = [];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    result = '${parts.join(',')},$last3';
  }
  return isNegative ? '-$result' : result;
}