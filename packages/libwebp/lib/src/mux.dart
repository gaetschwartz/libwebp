import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:libwebp/src/finalizers.dart';
import 'package:libwebp/src/libwebp.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart' as bindings;
import 'package:libwebp/src/utils.dart';
import 'package:meta/meta.dart';

class WebPMuxer implements Finalizable {
  final Pointer<bindings.WebPMux> _mux;
  bool _disposed = false;

  factory WebPMuxer() {
    final Pointer<bindings.WebPMux> mux = libwebp.WebPNewInternal(bindings.WEBP_MUX_ABI_VERSION);
    if (mux == nullptr) {
      throw LibWebPException('Failed to create WebPMux.');
    }
    final webPMuxer = WebPMuxer._(mux);

    muxFinalizer.attach(webPMuxer, mux, detach: webPMuxer);

    return webPMuxer;
  }

  WebPMuxer._(this._mux);

  void pushFrame(
    WebPMuxFrameInfo data, {
    bool copyData = false,
  }) {
    if (_disposed) {
      throw StateError('WebPMuxer already disposed.');
    }
    final int result = libwebp.WebPMuxPushFrame(
      _mux,
      data.ptr,
      copyData.c.value,
    );
    if (result != bindings.WebPMuxError.WEBP_MUX_OK) {
      throw LibWebPException('Failed to push frame to WebPMux: $result');
    }
  }

  WebPMuxAnimParams get animationParams {
    if (_disposed) {
      throw StateError('WebPMuxer already disposed.');
    }
    final params = WebPMuxAnimParams();
    final int result = libwebp.WebPMuxGetAnimationParams(_mux, params.ptr);
    if (result != bindings.WebPMuxError.WEBP_MUX_OK) {
      throw LibWebPException('Failed to get animation params from WebPMux: $result');
    }
    return params;
  }

  set animationParams(WebPMuxAnimParams params) {
    if (_disposed) {
      throw StateError('WebPMuxer already disposed.');
    }
    final int result = libwebp.WebPMuxSetAnimationParams(_mux, params.ptr);
    if (result != bindings.WebPMuxError.WEBP_MUX_OK) {
      throw LibWebPException('Failed to set animation params to WebPMux: $result');
    }
  }

  void deleteFrame(int index) {
    if (_disposed) {
      throw StateError('WebPMuxer already disposed.');
    }
    final int result = libwebp.WebPMuxDeleteFrame(_mux, index);
    if (result != bindings.WebPMuxError.WEBP_MUX_OK) {
      throw LibWebPException('Failed to remove frame from WebPMux: $result');
    }
  }

  void setChunk(WebpChunk chunk, {bool copyData = false}) {
    if (_disposed) {
      throw StateError('WebPMuxer already disposed.');
    }
    using((a) {
      final Pointer<Utf8> nativeUtf8 = chunk.chunkType.toNativeUtf8(allocator: a);
      final List<int> data = chunk.data;
      final Pointer<Uint8> bytes = a.allocate<Uint8>(data.length);
      bytes.asTypedList(data.length).setAll(0, data);
      final Pointer<bindings.WebPData> webpdata = a<bindings.WebPData>()
        ..ref.bytes = bytes
        ..ref.size = data.length;

      final int result = libwebp.WebPMuxSetChunk(
        _mux,
        nativeUtf8.cast(),
        webpdata,
        copyData.c.value,
      );
      if (result != bindings.WebPMuxError.WEBP_MUX_OK) {
        throw LibWebPException('Failed to push chunk to WebPMux: $result');
      }
    });
  }

  WebPData assemble() {
    if (_disposed) {
      throw StateError('WebPMuxer already disposed.');
    }
    final webp = WebPData(freeInnerBuffer: true);
    final int result = libwebp.WebPMuxAssemble(_mux, webp.ptr);

    if (result != bindings.WebPMuxError.WEBP_MUX_OK) {
      throw LibWebPException('Failed to assemble WebP: $result');
    }

    return webp;
  }

  void free() {
    if (_disposed) {
      throw StateError('WebPMuxer already disposed.');
    }
    muxFinalizer.detach(this);
    libwebp.WebPMuxDelete(_mux);
    _disposed = true;
  }
}

final class WebPMuxFrameInfo implements Finalizable {
  @internal
  final Pointer<bindings.WebPMuxFrameInfo> ptr;
  bool _disposed = false;

  WebPMuxFrameInfo._() : ptr = calloc<bindings.WebPMuxFrameInfo>() {
    callocFinalizer.attach(this, ptr.cast(), detach: this);
  }

  /// Construct a fully populated [WebPMuxFrameInfo].
  ///
  /// [bitstream] may be a raw VP8/VP8L payload OR a complete single-image
  /// WebP file; the mux will extract what it needs.
  factory WebPMuxFrameInfo.fromBitstream({
    required WebPData bitstream,
    Duration duration = const Duration(milliseconds: 100),
    WebPMuxAnimDispose dispose = WebPMuxAnimDispose.none,
    WebPMuxAnimBlend blend = WebPMuxAnimBlend.noBlend,
    WebPChunkType chunkType = WebPChunkType.anmf,
    int xOffset = 0,
    int yOffset = 0,
  }) {
    final info = WebPMuxFrameInfo._();
    final bindings.WebPData raw = bitstream.ptr.ref;
    info.ptr.ref.bitstream.bytes = raw.bytes;
    info.ptr.ref.bitstream.size = raw.size;
    info.ptr.ref.duration = duration.inMilliseconds;
    info.ptr.ref.dispose_method = dispose.value;
    info.ptr.ref.blend_method = blend.value;
    info.ptr.ref.id = chunkType._value;
    info.ptr.ref.x_offset = xOffset;
    info.ptr.ref.y_offset = yOffset;
    return info;
  }

  /// image data: can be a raw VP8/VP8L bitstream
  /// or a single-image WebP file.
  bindings.WebPData get bitstream => ptr.ref.bitstream;

  /// x-offset of the frame.
  int get xOffset => ptr.ref.x_offset;

  /// x-offset of the frame.
  set xOffset(int value) {
    ptr.ref.x_offset = value;
  }

  /// y-offset of the frame.
  int get yOffset => ptr.ref.y_offset;

  /// y-offset of the frame.
  set yOffset(int value) {
    ptr.ref.y_offset = value;
  }

  /// duration of the frame.
  Duration get duration => Duration(milliseconds: ptr.ref.duration);

  /// duration of the frame.
  set duration(Duration value) {
    ptr.ref.duration = value.inMilliseconds;
  }

  /// dispose of the frame.
  WebPMuxAnimDispose get dispose => WebPMuxAnimDispose.fromInt(ptr.ref.dispose_method);

  /// dispose of the frame.
  set dispose(WebPMuxAnimDispose value) {
    ptr.ref.dispose_method = value.value;
  }

  /// blend operation for the frame.
  WebPMuxAnimBlend get blend => WebPMuxAnimBlend.fromInt(ptr.ref.blend_method);

  /// blend operation for the frame.
  set blend(WebPMuxAnimBlend value) {
    ptr.ref.blend_method = value.value;
  }

  /// frame type: should be one of WEBP_CHUNK_ANMF
  /// or WEBP_CHUNK_IMAGE
  WebPChunkType get chunkType => WebPChunkType._(ptr.ref.id);

  /// frame type: should be one of WEBP_CHUNK_ANMF
  /// or WEBP_CHUNK_IMAGE
  set chunkType(WebPChunkType value) {
    ptr.ref.id = value._value;
  }

  void free() {
    if (_disposed) {
      throw StateError('WebPMuxFrameInfo already disposed.');
    }
    calloc.free(ptr);
    callocFinalizer.detach(this);
    _disposed = true;
  }
}

enum WebPMuxAnimDispose {
  /// Do not dispose.
  none(0),

  /// Dispose to background color.
  background(1),
  ;

  final int value;

  const WebPMuxAnimDispose(this.value);

  factory WebPMuxAnimDispose.fromInt(int value) => WebPMuxAnimDispose.values.firstWhere(
        (e) => e.value == value,
        orElse: () => throw ArgumentError.value(
          value,
          'value',
          'Invalid WebPMuxAnimDispose',
        ),
      );
}

enum WebPMuxAnimBlend {
  /// No blending.
  noBlend(0),

  /// Blend.
  blend(1),
  ;

  final int value;

  const WebPMuxAnimBlend(this.value);

  factory WebPMuxAnimBlend.fromInt(int value) => WebPMuxAnimBlend.values.firstWhere(
        (e) => e.value == value,
        orElse: () => throw ArgumentError.value(
          value,
          'value',
          'Invalid WebPMuxAnimBlend',
        ),
      );
}

extension type const WebPChunkType._(int _value) {
  static const vp8x = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_VP8X);
  static const iccp = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_ICCP);
  static const anim = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_ANIM);
  static const anmf = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_ANMF);
  static const deprecated = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_DEPRECATED);
  static const alpha = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_ALPHA);
  static const image = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_IMAGE);
  static const exif = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_EXIF);
  static const xmp = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_XMP);
  static const unknown = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_UNKNOWN);
  static const nil = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_NIL);

  static const values = [
    vp8x,
    iccp,
    anim,
    anmf,
    deprecated,
    alpha,
    image,
    exif,
    xmp,
    unknown,
    nil,
  ];
}

final class WebPMuxAnimParams extends CallocFinalizable<bindings.WebPMuxAnimParams> {
  /// Background color of the canvas stored (in MSB order) as:
  /// Bits 00 to 07: Alpha.
  /// Bits 08 to 15: Red.
  /// Bits 16 to 23: Green.
  /// Bits 24 to 31: Blue.
  int get bgcolor => ptr.ref.bgcolor;

  /// Number of times to repeat the animation [0 = infinite].
  int get loopCount => ptr.ref.loop_count;

  static const infiniteLoop = 0;

  factory WebPMuxAnimParams({
    int bgcolor = 0x00,
    int loopCount = infiniteLoop,
  }) {
    final p = WebPMuxAnimParams._();
    p.ptr.ref.bgcolor = bgcolor;
    p.ptr.ref.loop_count = loopCount;
    return p;
  }

  WebPMuxAnimParams._() : super(calloc<bindings.WebPMuxAnimParams>());
}

extension type const CBool(int value) {
  static const false_ = CBool(0);
  static const true_ = CBool(1);

  factory CBool.fromBool(bool value) => value ? true_ : false_;

  static const values = [false_, true_];
}

extension BoolToCBool on bool {
  CBool get c => CBool.fromBool(this);
}

/// Walks the chunk list of a single-image WebP file and returns the
/// concatenation of only the bitstream-level chunks that are valid inside an
/// ANMF frame-data field (`ALPH`, `ICCP`, `VP8 ` with trailing space, `VP8L`)
/// together with a flag indicating whether the source carries alpha.
///
/// The outer `RIFF`/`WEBP` framing and any `VP8X` chunk are skipped so the
/// result can be embedded directly into an ANMF payload.
///
/// Alpha detection:
/// - An `ALPH` chunk is the explicit alpha channel for lossy VP8 frames.
/// - A `VP8L` chunk may embed alpha directly; we check the alpha-is-used bit
///   at byte offset 4 of the VP8L payload (bit 4), as documented in the
///   libwebp VP8L spec and `src/enc/vp8l_enc.c`.
/// Bitstream-level chunks for a 1×1 fully-transparent placeholder frame,
/// suitable for embedding inside an ANMF payload. Computed once per isolate
/// at first use of [wrapSingleFrameAsAnimated].
///
/// Encoded as lossless VP8L so libwebp preserves the alpha channel exactly
/// (lossy at quality 0 may round transparent pixels to opaque). The full
/// returned chunk concatenation is ~30 bytes — much cheaper than duplicating
/// the source frame to satisfy `frameCount > 1`.
late final Uint8List _placeholderFrameChunks = _encodePlaceholderFrameChunks();

Uint8List _encodePlaceholderFrameChunks() {
  final config = WebPConfig(preset: WebPPreset.default_, quality: 100);
  config.lossless = 1;
  final encoder = WebPAnimEncoder(
    width: 1,
    height: 1,
    config: config,
    options: WebPAnimEncoderOptions(minimizeSize: false),
  );
  using((a) {
    final ptr = a.allocate<Uint8>(4);
    ptr.asTypedList(4).setAll(0, [0, 0, 0, 0]); // RGBA: fully transparent
    encoder.addFrames([
      (rgba: ptr, w: 1, h: 1, duration: const Duration(milliseconds: 8)),
    ]);
  });
  final webp = encoder.assemble();
  encoder.free();
  try {
    return _extractFrameChunks(webp.asTypedList).chunks;
  } finally {
    webp.free();
  }
}

({Uint8List chunks, bool hasAlpha}) _extractFrameChunks(Uint8List webp) {
  if (webp.length < 12 ||
      String.fromCharCodes(webp.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(webp.sublist(8, 12)) != 'WEBP') {
    throw LibWebPException('wrapSingleFrameAsAnimated: input is not a WebP');
  }
  const kept = {'ALPH', 'ICCP', 'VP8 ', 'VP8L'};
  final out = BytesBuilder();
  var hasAlpha = false;
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
      if (cc == 'ALPH') hasAlpha = true;
    }
    // VP8L has built-in alpha — check the alpha-is-used bit at payload
    // byte 4, bit 4.  VP8L payload layout: bytes 0-3 encode signature +
    // packed width/height; byte 4 bit 4 is alpha_is_used.
    if (cc == 'VP8L' && size >= 5) {
      final alphaIsUsedBit = (webp[pos + 8 + 4] >> 4) & 0x01;
      if (alphaIsUsedBit == 1) hasAlpha = true;
    }
    pos = chunkEnd;
  }
  return (chunks: out.toBytes(), hasAlpha: hasAlpha);
}

/// Mux a single-frame WebP (VP8/VP8L or complete single-image WebP) into a
/// 2×ANMF animated container (VP8X + ANIM + ANMF + ANMF). Useful when a
/// downstream consumer demands every sticker in an "animated" pack to be a
/// real animation, even when semantically static.
///
/// WhatsApp's third-party sticker validator rejects any sticker in an
/// animated pack with `frameCount <= 1` ("this pack is marked as animated
/// sticker pack, all stickers should animate.") — so a single-ANMF wrap
/// is silently discarded. This helper inserts a tiny 1×1 fully-transparent
/// placeholder ANMF as the second frame, composited with alpha-blend on
/// top of the first frame. Because the placeholder pixel has alpha=0,
/// alpha-blend reduces to "canvas pixel unchanged" — the animation is
/// visually a still image, but `frameCount` is 2.
///
/// libwebp's `WebPMuxAssemble` intentionally collapses single-frame
/// animations back to a plain WebP. To avoid this and to give us full
/// control over the ANIM/ANMF flag bytes (which WhatsApp also validates),
/// this helper manually constructs the RIFF container in Dart without
/// re-encoding the input bitstream.
///
/// [duration] is the duration of the visible (first) frame. The placeholder
/// second frame uses the WhatsApp-minimum 8ms.
///
/// Ownership: the caller is responsible for freeing [singleFrame] after this
/// returns; the returned [WebPData] owns its buffer independently.
WebPData wrapSingleFrameAsAnimated(
  WebPData singleFrame, {
  Duration duration = const Duration(milliseconds: 992),
  int loopCount = WebPMuxAnimParams.infiniteLoop,
}) {
  // Parse the input to obtain canvas dimensions.
  final Pointer<bindings.WebPMux> srcMux = libwebp.WebPMuxCreateInternal(
    singleFrame.ptr,
    0 /* copy_data = false */,
    bindings.WEBP_MUX_ABI_VERSION,
  );
  if (srcMux == nullptr) {
    throw LibWebPException('wrapSingleFrameAsAnimated: failed to parse input WebP');
  }
  int canvasW;
  int canvasH;
  try {
    final Pointer<Int> wPtr = calloc<Int>();
    final Pointer<Int> hPtr = calloc<Int>();
    try {
      final int err = libwebp.WebPMuxGetCanvasSize(srcMux, wPtr, hPtr);
      if (err != bindings.WebPMuxError.WEBP_MUX_OK) {
        throw LibWebPException(
            'wrapSingleFrameAsAnimated: WebPMuxGetCanvasSize failed: $err');
      }
      canvasW = wPtr.value;
      canvasH = hPtr.value;
    } finally {
      calloc.free(wPtr);
      calloc.free(hPtr);
    }
  } finally {
    libwebp.WebPMuxDelete(srcMux);
  }

  // Build the RIFF container manually:
  //   RIFF WEBP VP8X ANIM ANMF(<frame-data>) ANMF(<placeholder>)
  //
  // Per the WebP container spec, ANMF frame data must contain only
  // bitstream-level chunks (ALPH?, ICCP?, VP8 or VP8L).  The outer
  // RIFF/WEBP header and any VP8X chunk from the source file must be
  // stripped; libwebp's demuxer rejects files that embed a full
  // single-image WebP inside an ANMF payload.
  final extracted = _extractFrameChunks(singleFrame.asTypedList);
  final Uint8List frameChunks = extracted.chunks;
  final bool hasAlpha = extracted.hasAlpha;
  final int durationMs = duration.inMilliseconds.clamp(0, 0xFFFFFF);

  // 1×1 fully-transparent placeholder for ANMF #2 — see header doc.
  final Uint8List placeholderChunks = _placeholderFrameChunks;
  const int placeholderDurationMs = 8; // WhatsApp's documented minimum.

  // ANMF payload: 16-byte header + frame bitstream.
  //   x_offset/2 (3), y_offset/2 (3), width-1 (3), height-1 (3),
  //   duration (3), flags (1) = 16 bytes.
  final int anmf1PayloadSize = 16 + frameChunks.length;
  final int anmf1Padded = anmf1PayloadSize + (anmf1PayloadSize & 1);
  final int anmf2PayloadSize = 16 + placeholderChunks.length;
  final int anmf2Padded = anmf2PayloadSize + (anmf2PayloadSize & 1);

  // VP8X payload: flags (4) + canvas_width-1 (3) + canvas_height-1 (3) = 10 bytes.
  // ANIM payload: bgcolor (4) + loop_count (2) = 6 bytes.
  // Total RIFF data after "WEBP":
  //   VP8X: 8 (hdr) + 10 = 18
  //   ANIM: 8 (hdr) + 6  = 14
  //   ANMF1: 8 (hdr) + anmf1Padded
  //   ANMF2: 8 (hdr) + anmf2Padded
  final int riffPayloadSize = 4 + 18 + 14 + 8 + anmf1Padded + 8 + anmf2Padded;
  final int totalSize = 8 + riffPayloadSize; // 8 = "RIFF" + size field

  final buf = Uint8List(totalSize);
  var pos = 0;

  void setStr(String s) {
    for (final int c in s.codeUnits) {
      buf[pos++] = c;
    }
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

  void setU8(int v) => buf[pos++] = v & 0xFF;

  // RIFF header
  setStr('RIFF');
  setLE32(riffPayloadSize);
  setStr('WEBP');

  // VP8X chunk — animation flag (bit 1) always set; alpha flag (bit 4) when
  // the source carries an ALPH chunk or VP8L-with-alpha.
  setStr('VP8X');
  setLE32(10); // chunk size
  final int vp8xFlags = 0x00000002 | (hasAlpha ? 0x00000010 : 0);
  setLE32(vp8xFlags);
  setLE24(canvasW - 1);
  setLE24(canvasH - 1);

  // ANIM chunk — 0xffffffff matches WebPAnimEncoderOptionsInit's default
  // and what every working WhatsApp animated sticker carries; 0x00000000
  // (transparent black) is structurally legal but trips WhatsApp's
  // validator.
  setStr('ANIM');
  setLE32(6); // chunk size
  setLE32(0xffffffff); // bgcolor: opaque white (libwebp default)
  buf[pos++] = loopCount & 0xFF;
  buf[pos++] = (loopCount >> 8) & 0xFF;

  // ANMF #1 — the visible sticker frame, full canvas.
  // flags = 0x02 (NO_BLEND, dispose=none): replace the canvas wholesale,
  // matching every frame produced by WebPAnimEncoder for animated stickers.
  setStr('ANMF');
  setLE32(anmf1PayloadSize);
  setLE24(0); // x_offset / 2
  setLE24(0); // y_offset / 2
  setLE24(canvasW - 1);
  setLE24(canvasH - 1);
  setLE24(durationMs);
  setU8(0x02);
  buf.setAll(pos, frameChunks);
  pos += frameChunks.length;
  if (anmf1PayloadSize & 1 != 0) buf[pos++] = 0; // padding

  // ANMF #2 — 1×1 fully-transparent placeholder at (0,0).
  // flags = 0x00 (alpha-blend, dispose=none): src.alpha = 0 → canvas pixel
  // unchanged → animation is visually identical to a still image while
  // satisfying frameCount > 1.
  setStr('ANMF');
  setLE32(anmf2PayloadSize);
  setLE24(0); // x_offset / 2
  setLE24(0); // y_offset / 2
  setLE24(0); // width - 1  → 1 px
  setLE24(0); // height - 1 → 1 px
  setLE24(placeholderDurationMs);
  setU8(0x00);
  buf.setAll(pos, placeholderChunks);
  pos += placeholderChunks.length;
  if (anmf2PayloadSize & 1 != 0) buf[pos++] = 0; // padding

  // Copy into a calloc-owned WebPData that the caller can free normally.
  final Pointer<Uint8> outPtr = calloc<Uint8>(totalSize);
  outPtr.asTypedList(totalSize).setAll(0, buf);

  final result = WebPData(freeInnerBuffer: true);
  result.bytes = outPtr;
  result.size = totalSize;
  return result;
}

sealed class WebpChunk {
  List<int> get data;
  String get chunkType;

  (Pointer<bindings.WebPData>, Pointer<Uint8>) toNative(Allocator a) {
    assert(chunkType.length == 4, 'Chunk type must be 4 characters long.');
    final Pointer<Utf8> nativeUtf8 = chunkType.toNativeUtf8(allocator: a);
    final List<int> data = this.data;
    final Pointer<Uint8> bytes = a.allocate<Uint8>(data.length);
    bytes.asTypedList(data.length).setAll(0, data);
    final Pointer<bindings.WebPData> webpdata = a<bindings.WebPData>()
      ..ref.bytes = bytes
      ..ref.size = data.length;
    return (webpdata, nativeUtf8.cast());
  }

  const WebpChunk();
}
