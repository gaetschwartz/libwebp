import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:test/test.dart';

void main() {
  test('wrapSingleFrameAsAnimated produces a round-trippable animated WebP', () {
    final config = WebPConfig(preset: WebPPreset.default_, quality: 80);
    final encoder = WebPAnimEncoder(
      width: 8,
      height: 8,
      config: config,
      options: WebPAnimEncoderOptions(minimizeSize: false),
    );
    final rgba = Uint8List.fromList(List.filled(8 * 8 * 4, 0xff));
    using((a) {
      final ptr = a.allocate<Uint8>(8 * 8 * 4);
      ptr.asTypedList(8 * 8 * 4).setAll(0, rgba);
      encoder.addFrames([
        (rgba: ptr, w: 8, h: 8, duration: const Duration(milliseconds: 40)),
      ]);
    });
    final plain = encoder.assemble();
    encoder.free();

    // Sanity: plain output contains no ANIM chunk.
    expect(_hasChunk(plain.asTypedList, 'ANIM'), isFalse,
        reason: 'single-frame WebPAnimEncoder output should be plain WebP');

    final wrapped = wrapSingleFrameAsAnimated(
      plain,
      duration: const Duration(milliseconds: 100),
    );
    try {
      // Chunk-presence sanity checks.
      expect(_hasChunk(wrapped.asTypedList, 'VP8X'), isTrue);
      expect(_hasChunk(wrapped.asTypedList, 'ANIM'), isTrue);
      expect(_hasChunk(wrapped.asTypedList, 'ANMF'), isTrue);

      // Actual round-trip through libwebp's own anim decoder.
      final decoded = WebPImage(wrapped.asTypedList);
      expect(decoded.info.frameCount, 1);
      expect(decoded.info.canvasWidth, 8);
      expect(decoded.info.canvasHeight, 8);
      expect(decoded.framesMetadata, hasLength(1));
      expect(decoded.framesMetadata.first.duration.inMilliseconds, 100);
    } finally {
      wrapped.free();
    }
    plain.free();
  });
}

bool _hasChunk(Uint8List buf, String fourcc) {
  if (buf.length < 12 || String.fromCharCodes(buf.sublist(0, 4)) != 'RIFF') {
    return false;
  }
  var pos = 12;
  while (pos + 8 <= buf.length) {
    final cc = String.fromCharCodes(buf.sublist(pos, pos + 4));
    final size =
        buf[pos + 4] |
        (buf[pos + 5] << 8) |
        (buf[pos + 6] << 16) |
        (buf[pos + 7] << 24);
    if (cc == fourcc) return true;
    pos += 8 + size + (size & 1);
  }
  return false;
}
