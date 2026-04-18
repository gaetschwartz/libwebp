import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:test/test.dart';

void main() {
  test('wrapSingleFrameAsAnimated produces an ANIM-containing WebP', () {
    // Encode a tiny (1x1) still WebP using the anim encoder; the encoder
    // collapses 1-frame input to a plain WebP with no ANIM chunk — which
    // is exactly the input shape the helper exists to fix.
    final config = WebPConfig(preset: WebPPreset.default_, quality: 80);
    final encoder = WebPAnimEncoder(
      width: 1,
      height: 1,
      config: config,
      options: WebPAnimEncoderOptions(minimizeSize: false),
    );
    final rgba = Uint8List.fromList([0xff, 0x00, 0x00, 0xff]);
    using((a) {
      final ptr = a.allocate<Uint8>(4);
      ptr.asTypedList(4).setAll(0, rgba);
      encoder.addFrames([
        (rgba: ptr, w: 1, h: 1, duration: const Duration(milliseconds: 40)),
      ]);
    });
    final plain = encoder.assemble();

    // Sanity: plain output contains no ANIM chunk.
    expect(_hasChunk(plain.asTypedList, 'ANIM'), isFalse,
        reason: 'single-frame WebPAnimEncoder output should be plain WebP');

    final wrapped = wrapSingleFrameAsAnimated(plain);

    // Safe to free encoder after wrapping (wrapSingleFrameAsAnimated copies
    // the bytes internally).
    encoder.free();
    plain.free();

    try {
      expect(_hasChunk(wrapped.asTypedList, 'ANIM'), isTrue);
      expect(_hasChunk(wrapped.asTypedList, 'ANMF'), isTrue);
      expect(_hasChunk(wrapped.asTypedList, 'VP8X'), isTrue);
    } finally {
      wrapped.free();
    }
  });
}

bool _hasChunk(Uint8List buf, String fourcc) {
  if (buf.length < 12 || String.fromCharCodes(buf.sublist(0, 4)) != 'RIFF') {
    return false;
  }
  var pos = 12;
  while (pos + 8 <= buf.length) {
    final cc = String.fromCharCodes(buf.sublist(pos, pos + 4));
    final size = buf[pos + 4] |
        (buf[pos + 5] << 8) |
        (buf[pos + 6] << 16) |
        (buf[pos + 7] << 24);
    if (cc == fourcc) return true;
    pos += 8 + size + (size & 1);
  }
  return false;
}
