import 'dart:ffi';

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
    WebPConfig config,
    WebPMuxFrameInfo data, {
    bool copyData = false,
  }) {
    if (_disposed) {
      throw StateError('WebPMuxer already disposed.');
    }
    checkVp8(libwebp.WebPMuxPushFrame(
      _mux,
      data.ptr,
      copyData.c.value,
    ));
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
