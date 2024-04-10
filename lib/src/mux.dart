part of 'anim_encoder.dart';

class WebPMuxer implements Finalizable {
  final Pointer<bindings.WebPMux> _mux;
  bool _disposed = false;

  factory WebPMuxer() {
    final mux = libwebp.WebPNewInternal(bindings.WEBP_MUX_ABI_VERSION);
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
    final result = libwebp.WebPMuxPushFrame(
      _mux,
      data.ptr,
      copyData ? 1 : 0,
    );
    if (result != bindings.WebPMuxError.WEBP_MUX_OK) {
      throw LibWebPException('Failed to add frame to WebPMux: $result');
    }
  }

  WebPMuxAnimParams get animationParams {
    if (_disposed) {
      throw StateError('WebPMuxer already disposed.');
    }
    final params = WebPMuxAnimParams();
    final result = libwebp.WebPMuxGetAnimationParams(_mux, params.ptr);
    if (result != bindings.WebPMuxError.WEBP_MUX_OK) {
      throw LibWebPException(
          'Failed to get animation params from WebPMux: $result');
    }
    return params;
  }

  set animationParams(WebPMuxAnimParams params) {
    if (_disposed) {
      throw StateError('WebPMuxer already disposed.');
    }
    final result = libwebp.WebPMuxSetAnimationParams(_mux, params.ptr);
    if (result != bindings.WebPMuxError.WEBP_MUX_OK) {
      throw LibWebPException(
          'Failed to set animation params to WebPMux: $result');
    }
  }

  void deleteFrame(int index) {
    if (_disposed) {
      throw StateError('WebPMuxer already disposed.');
    }
    final result = libwebp.WebPMuxDeleteFrame(_mux, index);
    if (result != bindings.WebPMuxError.WEBP_MUX_OK) {
      throw LibWebPException('Failed to remove frame from WebPMux: $result');
    }
  }

  WebPData assemble() {
    if (_disposed) {
      throw StateError('WebPMuxer already disposed.');
    }
    final webp = WebPData(freeInnerBuffer: true);
    final result = libwebp.WebPMuxAssemble(_mux, webp.ptr);

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
  WebPMuxAnimDispose get dispose =>
      WebPMuxAnimDispose.fromInt(ptr.ref.dispose_method);

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

  factory WebPMuxAnimDispose.fromInt(int value) =>
      WebPMuxAnimDispose.values.firstWhere(
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

  factory WebPMuxAnimBlend.fromInt(int value) =>
      WebPMuxAnimBlend.values.firstWhere(
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
  static const deprecated =
      WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_DEPRECATED);
  static const alpha = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_ALPHA);
  static const image = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_IMAGE);
  static const exif = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_EXIF);
  static const xmp = WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_XMP);
  static const unknown =
      WebPChunkType._(bindings.WebPChunkId.WEBP_CHUNK_UNKNOWN);
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

final class WebPMuxAnimParams
    extends CallocFinalizable<bindings.WebPMuxAnimParams> {
  /// Background color of the canvas stored (in MSB order) as:
  /// Bits 00 to 07: Alpha.
  /// Bits 08 to 15: Red.
  /// Bits 16 to 23: Green.
  /// Bits 24 to 31: Blue.
  int get bgcolor => ptr.ref.bgcolor;
  set bgcolor(int value) {
    ptr.ref.bgcolor = value;
  }

  /// Number of times to repeat the animation [0 = infinite].
  int get loopCount => ptr.ref.loop_count;
  set loopCount(int value) {
    ptr.ref.loop_count = value;
  }

  static const infiniteLoop = 0;

  WebPMuxAnimParams() : super(calloc<bindings.WebPMuxAnimParams>());
}
