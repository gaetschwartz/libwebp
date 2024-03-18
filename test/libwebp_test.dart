import 'package:libwebp/src/libwebp.dart';
import 'package:test/test.dart';

void main() {
  test('parse version', () {
    final parsed = Version.fromInt(0x010203);
    expect(parsed.major, 1);
    expect(parsed.minor, 2);
    expect(parsed.patch, 3);
    expect(parsed.toString(), '1.2.3');
  });
}
