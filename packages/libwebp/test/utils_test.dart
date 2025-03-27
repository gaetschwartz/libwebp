import 'dart:ffi';

import 'package:libwebp/libwebp.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart';
import 'package:libwebp/src/utils.dart';
import 'package:test/test.dart';

void main() {
  test('checkAlloc', () {
    expect(
      () => checkAlloc<WebPAnimDecoder>(nullptr, 'Failed to allocate.'),
      throwsA(
        isA<LibWebPAllocException>().having((e) => e.objectName, 'objectName', 'WebPAnimDecoder'),
      ),
    );
  });

  group('animation timings', () {
    test('list', () {
      const timings = ListWebPAnimationTiming([
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 3),
      ]);
      expect(timings.at(0), const Duration(seconds: 1));
      expect(timings.at(1), const Duration(seconds: 2));
      expect(timings.at(2), const Duration(seconds: 3));
    });

    test('all', () {
      const timings = ConstantWebPAnimationTiming(Duration(seconds: 1), 3);
      expect(timings.at(0), const Duration(seconds: 1));
      expect(timings.at(1), const Duration(seconds: 1));
      expect(timings.at(2), const Duration(seconds: 1));
    });

    test('map', () {
      const length = 12;
      final source = ListWebPAnimationTiming(
        List.generate(length, (i) => Duration(seconds: i + 1)),
      );
      final timings = MappedWebPAnimationTiming(
        source,
        (index, duration) => index.isEven ? duration : duration * 2,
      );
      expect(List.generate(length, timings.at), [
        const Duration(seconds: 1),
        const Duration(seconds: 4),
        const Duration(seconds: 3),
        const Duration(seconds: 8),
        const Duration(seconds: 5),
        const Duration(seconds: 12),
        const Duration(seconds: 7),
        const Duration(seconds: 16),
        const Duration(seconds: 9),
        const Duration(seconds: 20),
        const Duration(seconds: 11),
        const Duration(seconds: 24),
      ]);
    });
  });
}
