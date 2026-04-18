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
      duration: const Duration(milliseconds: 500),
    );
    try {
      // Chunk-presence sanity checks.
      expect(_hasChunk(wrapped.asTypedList, 'VP8X'), isTrue);
      expect(_hasChunk(wrapped.asTypedList, 'ANIM'), isTrue);
      expect(_hasChunk(wrapped.asTypedList, 'ANMF'), isTrue);

      // Round-trip through libwebp's own anim decoder, which is the same
      // path WhatsApp uses to validate incoming stickers.
      final decoded = WebPImage(wrapped.asTypedList);
      // WhatsApp's animated-pack validator rejects frameCount <= 1 — the
      // wrap MUST emit two ANMF chunks (the visible frame + a 1×1
      // transparent placeholder).
      expect(decoded.info.frameCount, 2);
      expect(decoded.info.canvasWidth, 8);
      expect(decoded.info.canvasHeight, 8);
      expect(decoded.framesMetadata, hasLength(2));
      // Frame 1: full canvas, configured duration.
      expect(decoded.framesMetadata[0].width, 8);
      expect(decoded.framesMetadata[0].height, 8);
      expect(decoded.framesMetadata[0].duration.inMilliseconds, 500);
      // Frame 2: 1×1 placeholder, 8ms (WhatsApp minimum).
      expect(decoded.framesMetadata[1].width, 1);
      expect(decoded.framesMetadata[1].height, 1);
      expect(decoded.framesMetadata[1].duration.inMilliseconds, 8);
    } finally {
      wrapped.free();
    }
    plain.free();
  });

  test('wrapSingleFrameAsAnimated sets bgcolor=0xffffffff and frame1 NO_BLEND', () {
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

    final wrapped = wrapSingleFrameAsAnimated(plain);
    try {
      final bytes = wrapped.asTypedList;
      // Walk to ANIM and ANMF chunks; assert their flag bytes match what
      // WhatsApp's iOS importer expects (matches WebPAnimEncoder's own
      // output for real animated stickers).
      var pos = 12;
      int? animBgcolor;
      final anmfFlags = <int>[];
      while (pos + 8 <= bytes.length) {
        final cc = String.fromCharCodes(bytes.sublist(pos, pos + 4));
        final size = bytes[pos + 4] |
            (bytes[pos + 5] << 8) |
            (bytes[pos + 6] << 16) |
            (bytes[pos + 7] << 24);
        if (cc == 'ANIM') {
          animBgcolor = bytes[pos + 8] |
              (bytes[pos + 9] << 8) |
              (bytes[pos + 10] << 16) |
              (bytes[pos + 11] << 24);
        } else if (cc == 'ANMF') {
          // ANMF flags byte sits at payload offset 15.
          anmfFlags.add(bytes[pos + 8 + 15]);
        }
        pos += 8 + size + (size & 1);
      }
      expect(animBgcolor, 0xffffffff,
          reason: 'ANIM bgcolor must be opaque white (libwebp default)');
      expect(anmfFlags, hasLength(2));
      expect(anmfFlags[0], 0x02,
          reason: 'frame 1 must be NO_BLEND, dispose=none');
      expect(anmfFlags[1], 0x00,
          reason: 'frame 2 (placeholder) must be alpha-blend, dispose=none');
    } finally {
      wrapped.free();
    }
    plain.free();
  });

  test('wrapSingleFrameAsAnimated sets VP8X ALPHA_FLAG for alpha-bearing sources', () {
    final config = WebPConfig(preset: WebPPreset.default_, quality: 80);
    final encoder = WebPAnimEncoder(
      width: 8,
      height: 8,
      config: config,
      options: WebPAnimEncoderOptions(minimizeSize: false),
    );
    // RGBA with a translucent pixel somewhere to force alpha in the encode.
    final rgba = Uint8List(8 * 8 * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba[i] = 0x20;     // R
      rgba[i + 1] = 0x40; // G
      rgba[i + 2] = 0x80; // B
      rgba[i + 3] = 0x7f; // A (translucent)
    }
    using((a) {
      final ptr = a.allocate<Uint8>(8 * 8 * 4);
      ptr.asTypedList(8 * 8 * 4).setAll(0, rgba);
      encoder.addFrames([
        (rgba: ptr, w: 8, h: 8, duration: const Duration(milliseconds: 40)),
      ]);
    });
    final plain = encoder.assemble();
    encoder.free();

    final wrapped = wrapSingleFrameAsAnimated(plain);
    try {
      // Find the VP8X chunk header and read the flags byte (first byte of
      // the 4-byte flags LE32 at VP8X payload offset 0).
      final bytes = wrapped.asTypedList;
      var pos = 12;
      var foundVp8x = false;
      while (pos + 8 <= bytes.length) {
        final cc = String.fromCharCodes(bytes.sublist(pos, pos + 4));
        final size = bytes[pos + 4] |
            (bytes[pos + 5] << 8) |
            (bytes[pos + 6] << 16) |
            (bytes[pos + 7] << 24);
        if (cc == 'VP8X') {
          foundVp8x = true;
          final flags = bytes[pos + 8];
          expect(flags & 0x02, isNonZero, reason: 'VP8X animation flag must be set');
          expect(flags & 0x10, isNonZero,
              reason: 'VP8X alpha flag must be set when source has ALPH/VP8L-alpha');
          break;
        }
        pos += 8 + size + (size & 1);
      }
      expect(foundVp8x, isTrue);
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
