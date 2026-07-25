import 'package:flutter_test/flutter_test.dart';
import 'package:pulangaman/core/parse_coord.dart';

void main() {
  test('parseCoord accepts num and numeric strings', () {
    expect(parseCoord(-6.2), -6.2);
    expect(parseCoord(106), 106.0);
    expect(parseCoord('1.23'), 1.23);
    expect(parseCoord('  -6.201  '), -6.201);
    expect(parseCoord(null), isNull);
    expect(parseCoord('abc'), isNull);
  });
}
