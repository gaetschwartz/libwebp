import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:test/test.dart';

void main() {
  test('addFrames encodes a synthetic 2-frame 4×4 animation', () {
    final red = calloc<Uint8>(4 * 4 * 4);
    final green = calloc<Uint8>(4 * 4 * 4);
    for (var i = 0; i < 4 * 4; i++) {
      red[i * 4] = 255;        red[i * 4 + 3] = 255;
      green[i * 4 + 1] = 255;  green[i * 4 + 3] = 255;
    }
    try {
      final encoder = WebPAnimEncoder(
        width: 4,
        height: 4,
        config: WebPConfig(quality: 75),
      );
      encoder.addFrames([
        (rgba: red, w: 4, h: 4, duration: const Duration(milliseconds: 100)),
        (rgba: green, w: 4, h: 4, duration: const Duration(milliseconds: 100)),
      ]);
      final out = encoder.assemble();
      expect(out.asTypedList.lengthInBytes, greaterThan(0));
      out.free();
      encoder.free();
    } finally {
      calloc.free(red);
      calloc.free(green);
    }
  });
}
