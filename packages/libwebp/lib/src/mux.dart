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

/// Mux a single-frame WebP (VP8/VP8L or complete single-image WebP) into a
/// 1×ANMF animated container (VP8X + ANIM + ANMF). Useful when a downstream
/// consumer demands every sticker in an "animated" pack to carry the
/// animation chunks, even when semantically static.
///
/// libwebp's `WebPMuxAssemble` intentionally collapses a single-frame
/// animation back to a plain WebP. To avoid this, this helper manually
/// constructs the RIFF container in Dart without re-encoding.
///
/// Ownership: the caller is responsible for freeing [singleFrame] after this
/// returns; the returned [WebPData] owns its buffer independently.
WebPData wrapSingleFrameAsAnimated(
  WebPData singleFrame, {
  Duration duration = const Duration(milliseconds: 100),
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
  //   RIFF WEBP VP8X ANIM ANMF(<frame-data>)
  //
  // Frame data is the entire [singleFrame] buffer (a complete single-image
  // WebP), which is valid per the WebP container spec.
  final Uint8List frameBytes = singleFrame.asTypedList;
  final int durationMs = duration.inMilliseconds.clamp(0, 0xFFFFFF);

  // ANMF payload: 16-byte header + frame bitstream.
  //   x_offset/2 (3), y_offset/2 (3), width-1 (3), height-1 (3),
  //   duration (3), flags (1) = 16 bytes.
  final int anmfPayloadSize = 16 + frameBytes.length;
  final int anmfPadded = anmfPayloadSize + (anmfPayloadSize & 1); // RIFF 2-byte align

  // VP8X payload: flags (4) + canvas_width-1 (3) + canvas_height-1 (3) = 10 bytes.
  // ANIM payload: bgcolor (4) + loop_count (2) = 6 bytes.
  // Total RIFF data after "WEBP":
  //   VP8X: 8 (hdr) + 10 = 18
  //   ANIM: 8 (hdr) + 6  = 14
  //   ANMF: 8 (hdr) + anmfPadded
  final int riffPayloadSize = 4 + 18 + 14 + 8 + anmfPadded; // 4 = "WEBP"
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

  // VP8X chunk — animation flag (bit 1) set
  setStr('VP8X');
  setLE32(10); // chunk size
  setLE32(0x00000002); // flags: animation bit
  setLE24(canvasW - 1);
  setLE24(canvasH - 1);

  // ANIM chunk
  setStr('ANIM');
  setLE32(6); // chunk size
  setLE32(0x00000000); // bgcolor = transparent black
  buf[pos++] = loopCount & 0xFF;
  buf[pos++] = (loopCount >> 8) & 0xFF;

  // ANMF chunk
  setStr('ANMF');
  setLE32(anmfPayloadSize);
  setLE24(0); // x_offset / 2
  setLE24(0); // y_offset / 2
  setLE24(canvasW - 1);
  setLE24(canvasH - 1);
  setLE24(durationMs);
  setU8(0x00); // flags: no blend, no dispose
  buf.setAll(pos, frameBytes);
  pos += frameBytes.length;
  if (anmfPayloadSize & 1 != 0) buf[pos++] = 0; // padding

  // Copy into a calloc-owned WebPData that the caller can free normally.
  final Pointer<Uint8> outPtr = calloc<Uint8>(totalSize);
  outPtr.asTypedList(totalSize).setAll(0, buf);

  final result = WebPData();
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
