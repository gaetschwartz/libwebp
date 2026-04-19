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

  test('wrapSingleFrameAsAnimated descends into ANMF when input is animated-shape', () {
    // Regression for the 114-byte empty-wrap bug: when
    // WebPAnimEncoderAssemble's OptimizeSingleFrame doesn't collapse to
    // plain (because the animated container was already smaller),
    // _extractFrameChunks used to return an empty bitstream and the wrap
    // produced a ~114-byte container with a zero-payload ANMF. This test
    // hand-builds an animated-shape WebP (VP8X + ANIM + ANMF{header +
    // bitstream}) and asserts the wrapper extracts the inner bitstream
    // correctly.

    // First, produce a plain WebP via the encoder so we have a real VP8L
    // bitstream to embed — hand-crafting a valid VP8L stream is tedious
    // and version-fragile.
    final encoder = WebPAnimEncoder(
      width: 8,
      height: 8,
      config: WebPConfig(preset: WebPPreset.default_, quality: 80)..lossless = 1,
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

    final plainBytes = plain.asTypedList;
    // The plain output contains a top-level VP8L (or VP8+ALPH). Extract
    // that chunk verbatim — header + payload — to embed inside an ANMF.
    final inner = _extractBitstreamChunks(plainBytes);
    expect(inner, isNotEmpty,
        reason: 'plain single-frame encode must have a VP8/VP8L chunk');

    // Hand-build an animated-shape WebP wrapping `inner` in a single
    // ANMF. This is exactly the byte shape libwebp emits when
    // OptimizeSingleFrame keeps the animated container.
    const int canvasW = 8;
    const int canvasH = 8;
    final anmfPayloadSize = 16 + inner.length;
    final anmfPadded = anmfPayloadSize + (anmfPayloadSize & 1);
    final riffPayloadSize = 4 + 18 + 14 + 8 + anmfPadded;
    final totalSize = 8 + riffPayloadSize;

    final buf = Uint8List(totalSize);
    var pos = 0;
    void setStr(String s) {
      for (final c in s.codeUnits) buf[pos++] = c;
    }
    void setLE32(int v) {
      buf[pos++] = v & 0xFF;
      buf[pos++] = (v >> 8) & 0xFF;
      buf[pos++] = (v >> 16) & 0xFF;
      buf[pos++] = (v >> 24) & 0xFF;
    }
    void setLE24(int v) {
      buf[pos++] = v & 0xFF;
      buf[pos++] = (v >> 8) & 0xFF;
      buf[pos++] = (v >> 16) & 0xFF;
    }

    setStr('RIFF');
    setLE32(riffPayloadSize);
    setStr('WEBP');
    // VP8X: animation + alpha.
    setStr('VP8X');
    setLE32(10);
    setLE32(0x00000012);
    setLE24(canvasW - 1);
    setLE24(canvasH - 1);
    // ANIM: opaque-white bg, infinite loop.
    setStr('ANIM');
    setLE32(6);
    setLE32(0xffffffff);
    buf[pos++] = 0;
    buf[pos++] = 0;
    // ANMF: full-canvas frame with duration and NO_BLEND dispose=none.
    setStr('ANMF');
    setLE32(anmfPayloadSize);
    setLE24(0); // x_offset / 2
    setLE24(0); // y_offset / 2
    setLE24(canvasW - 1);
    setLE24(canvasH - 1);
    setLE24(100); // duration
    buf[pos++] = 0x02;
    buf.setRange(pos, pos + inner.length, inner);
    pos += inner.length;
    if (anmfPayloadSize & 1 != 0) buf[pos++] = 0;

    expect(pos, totalSize, reason: 'synthetic animated WebP built to expected size');
    // Sanity: our synthetic input is the shape we claim.
    expect(_hasChunk(buf, 'ANIM'), isTrue);
    expect(_hasChunk(buf, 'ANMF'), isTrue);

    // Wrap the synthetic input through a WebPData so the helper can
    // parse its canvas size.
    final synthetic = _webPDataFromBytes(buf);
    try {
      final wrapped = wrapSingleFrameAsAnimated(synthetic);
      try {
        // The wrap output MUST contain the real bitstream (not a 114-byte
        // empty shell). Before the fix this was ~114 bytes.
        expect(wrapped.asTypedList.length, greaterThan(inner.length),
            reason: 'wrap output must carry the inner bitstream, not be an '
                'empty-frame shell');

        final decoded = WebPImage(Uint8List.fromList(wrapped.asTypedList));
        expect(decoded.info.frameCount, 2);
        expect(decoded.info.canvasWidth, canvasW);
        expect(decoded.info.canvasHeight, canvasH);
        expect(decoded.framesMetadata[0].width, canvasW);
        expect(decoded.framesMetadata[0].height, canvasH);
        expect(decoded.framesMetadata[1].width, 1);
        expect(decoded.framesMetadata[1].height, 1);
      } finally {
        wrapped.free();
      }
    } finally {
      synthetic.free();
    }
    plain.free();
  });
}

/// Copy top-level VP8/VP8L/ALPH chunks (header+payload+padding) out of a
/// plain WebP so we can embed them as bitstream data inside a synthetic
/// ANMF payload.
Uint8List _extractBitstreamChunks(Uint8List webp) {
  const kept = {'ALPH', 'ICCP', 'VP8 ', 'VP8L'};
  final out = BytesBuilder();
  var pos = 12;
  while (pos + 8 <= webp.length) {
    final cc = String.fromCharCodes(webp.sublist(pos, pos + 4));
    final size = webp[pos + 4] |
        (webp[pos + 5] << 8) |
        (webp[pos + 6] << 16) |
        (webp[pos + 7] << 24);
    final padded = size + (size & 1);
    final chunkEnd = pos + 8 + padded;
    if (chunkEnd > webp.length) break;
    if (kept.contains(cc)) {
      out.add(webp.sublist(pos, chunkEnd));
    }
    pos = chunkEnd;
  }
  return out.toBytes();
}

/// Build a [WebPData] around an owned copy of [bytes] so the mux helpers
/// can read it as if it came from libwebp.
WebPData _webPDataFromBytes(Uint8List bytes) {
  final data = WebPData(freeInnerBuffer: true);
  final ptr = calloc<Uint8>(bytes.length);
  ptr.asTypedList(bytes.length).setAll(0, bytes);
  data.bytes = ptr;
  data.size = bytes.length;
  return data;
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
