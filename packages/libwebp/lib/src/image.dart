import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:libwebp/src/finalizers.dart';
import 'package:libwebp/src/libwebp.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart' as bindings;
import 'package:libwebp/src/utils.dart';
import 'package:meta/meta.dart';

typedef WebPDecoderFinalizable = ({Arena arena, Pointer<bindings.WebPAnimDecoder> decoder});

class WebPImage implements Finalizable {
  // Held to keep the source bytes alive while the decoder holds a
  // pointer into them (WebPAnimDecoderNewInternal doesn't copy).
  // ignore: unused_field
  final FfiByteData _data;
  final _WebPAnimDecoder _decoder;

  // --- decoded-frame cache (lazy, grows monotonically) ---
  //
  // Invariant: `_decoder`'s internal cursor is always at
  // `_cachedRgba?.length ?? 0`. We only advance the decoder via
  // `_decodeNextInto`, which appends exactly one slot. This means
  // iterators can freely start/resume over `frames` without ever needing
  // `WebPAnimDecoderReset` — cache hits skip the decoder entirely, and
  // the first iteration that reaches frame N is the one that decodes it.
  List<Pointer<Uint8>>? _cachedRgba;
  Pointer<Uint8>? _cacheBuffer;
  Pointer<Pointer<Uint8>>? _cacheFrameOut;
  Pointer<Int>? _cacheTsOut;

  factory WebPImage(Uint8List data) {
    final d = FfiByteData.fromTypedList(data);
    return WebPImage.native(d);
  }

  factory WebPImage.native(FfiByteData data) {
    final decoder = _WebPAnimDecoder(data);

    return WebPImage._(
      data: data,
      decoder: decoder,
    );
  }

  WebPImage._({
    required FfiByteData data,
    required _WebPAnimDecoder decoder,
  })  : _data = data,
        _decoder = decoder;

  WebPAnimInfo get info => _decoder.info;

  /// Cheap, demuxer-only per-frame metadata (durations, offsets, blend
  /// modes, etc.). One-shot populated on first access.
  ///
  /// Reading durations or counting frames through this does NOT trigger
  /// any VP8 pixel decoding — use [frames] for that.
  late final List<WebPFrameMetadata> framesMetadata = _readFramesMetadata();

  /// Sequential iterator over decoded frames.
  ///
  /// Each `moveNext` populates (or hits) a lazily-grown cache on this
  /// image. Iterating once through N frames pays N decodes; a second
  /// iteration on the same image pays zero — every `moveNext` returns a
  /// `WebPFrame` whose [rgba] pointer is already in cache. Intended use:
  /// multi-pass re-encoding ladders that replay the same source through
  /// several encoders.
  Iterable<WebPFrame> get frames => WebPImageFramesIterable(this);

  late final timings = ListWebPAnimationTiming(
    framesMetadata.map((m) => m.duration).toList(growable: false),
  );

  double get fps => 1000 * info.frameCount / timings.value.last.inMilliseconds;

  Duration get averageFrameDuration => timings.value.last ~/ timings.value.length;

  List<WebPFrameMetadata> _readFramesMetadata() {
    final Pointer<bindings.WebPDemuxer> demuxer = checkAlloc(
      libwebp.WebPAnimDecoderGetDemuxer(_decoder.ptr),
      'Failed to get WebPDemuxer.',
    );
    final Pointer<bindings.WebPIterator> iter = calloc<bindings.WebPIterator>();
    try {
      if (!libwebp.WebPDemuxGetFrame(demuxer, 1, iter).asCBoolean) {
        return const [];
      }
      final List<WebPFrameMetadata> list = [];
      do {
        list.add(
          WebPFrameMetadata(
            frameNum: iter.ref.frame_num,
            numFrames: iter.ref.num_frames,
            xOffset: iter.ref.x_offset,
            yOffset: iter.ref.y_offset,
            width: iter.ref.width,
            height: iter.ref.height,
            duration: Duration(milliseconds: iter.ref.duration),
            dispose: WebPMuxAnimDispose.fromInt(iter.ref.dispose_method),
            blend: WebPMuxAnimBlend.fromInt(iter.ref.blend_method),
            hasAlpha: iter.ref.has_alpha != 0,
            complete: iter.ref.complete != 0,
          ),
        );
      } while (libwebp.WebPDemuxNextFrame(iter).asCBoolean);
      return List<WebPFrameMetadata>.unmodifiable(list);
    } finally {
      libwebp.WebPDemuxReleaseIterator(iter);
      calloc.free(iter);
    }
  }

  /// Returns the decoded RGBA pointer for frame at [index] (0-based).
  /// Sequential-only: accessing index `i` requires the cache to already
  /// hold 0..i-1 (the iterator enforces this).
  @internal
  Pointer<Uint8> ensureDecodedAt(int index) {
    final cache = _cachedRgba ??= <Pointer<Uint8>>[];
    if (index < cache.length) return cache[index];
    if (index != cache.length) {
      throw StateError(
        'Non-sequential frame access: requested $index but cache holds ${cache.length}. '
        'frames only supports forward iteration.',
      );
    }

    // Lazy-init the shared backing buffer on the first actual decode.
    // (Avoids the allocation for callers that never touch `.rgba`.)
    final int stride = info.canvasWidth * info.canvasHeight * 4;
    if (_cacheBuffer == null) {
      _cacheBuffer = calloc<Uint8>(stride * info.frameCount);
      _cacheFrameOut = calloc<Pointer<Uint8>>();
      _cacheTsOut = calloc<Int>();
      callocFinalizer.attach(this, _cacheBuffer!.cast(), detach: this);
      callocFinalizer.attach(this, _cacheFrameOut!.cast(), detach: this);
      callocFinalizer.attach(this, _cacheTsOut!.cast(), detach: this);
    }

    if (!_decoder.getNext(_cacheFrameOut!, _cacheTsOut!)) {
      throw StateError(
        'WebPAnimDecoderGetNext returned false at frame $index/${info.frameCount}',
      );
    }
    final Pointer<Uint8> slot = Pointer<Uint8>.fromAddress(
      _cacheBuffer!.address + index * stride,
    );
    slot.asTypedList(stride).setAll(0, _cacheFrameOut!.value.asTypedList(stride));
    cache.add(slot);
    return slot;
  }
}

/// Pure demuxer-sourced metadata for a single frame. Cheap to produce
/// and holds no references back to the WebPImage.
final class WebPFrameMetadata {
  /// 1-based frame index as reported by the demuxer.
  final int frameNum;
  final int numFrames;
  final int xOffset;
  final int yOffset;
  final int width;
  final int height;
  final Duration duration;
  final WebPMuxAnimDispose dispose;
  final WebPMuxAnimBlend blend;
  final bool hasAlpha;
  final bool complete;

  const WebPFrameMetadata({
    required this.frameNum,
    required this.numFrames,
    required this.xOffset,
    required this.yOffset,
    required this.width,
    required this.height,
    required this.duration,
    required this.dispose,
    required this.blend,
    required this.hasAlpha,
    required this.complete,
  });
}

/// A frame yielded by [WebPImage.frames]. Combines the demuxer metadata
/// with a stable RGBA pointer owned by the parent [WebPImage]; [rgba] is
/// valid as long as the image is reachable.
final class WebPFrame {
  final WebPImage _image;

  /// Per-frame metadata. Shared structurally with [WebPImage.framesMetadata].
  final WebPFrameMetadata metadata;

  /// Decoded RGBA (canvas-sized, not per-frame subregion) lazily cached
  /// on the parent [WebPImage]. Valid until the image is garbage collected.
  final Pointer<Uint8> rgba;

  int get width => _image.info.canvasWidth;
  int get height => _image.info.canvasHeight;
  int get frameNum => metadata.frameNum;
  Duration get duration => metadata.duration;

  const WebPFrame._({
    required WebPImage image,
    required this.metadata,
    required this.rgba,
  }) : _image = image;

  /// Re-encode this single frame as a standalone (non-animated) WebP.
  /// Useful for producing tray thumbnails.
  Uint8List encode({
    double quality = 100,
    ({int width, int height})? targetDimensions,
  }) {
    return using((alloc) {
      final Pointer<bindings.WebPPicture> pic = alloc<bindings.WebPPicture>();
      check(
        libwebp.WebPPictureInitInternal(pic, bindings.WEBP_ENCODER_ABI_VERSION),
        'Failed to init WebPPicture.',
      );
      pic.ref.use_argb = 1;
      pic.ref.width = width;
      pic.ref.height = height;

      check(
        libwebp.WebPPictureImportRGBA(pic, rgba, width * 4),
        'Failed to import frame to WebPPicture.',
      );

      if (targetDimensions case final dim?) {
        check(
          libwebp.WebPPictureRescale(pic, dim.width, dim.height),
          'Failed to rescale frame.',
        );
      }

      final Pointer<bindings.WebPConfig> cfg = alloc<bindings.WebPConfig>();
      check(
        libwebp.WebPConfigInitInternal(
          cfg,
          bindings.WebPPreset.WEBP_PRESET_DEFAULT,
          quality,
          bindings.WEBP_ENCODER_ABI_VERSION,
        ),
        'Failed to init WebPConfig.',
      );
      final Pointer<bindings.WebPMemoryWriter> writer = alloc<bindings.WebPMemoryWriter>();
      writer.ref.mem = nullptr;
      writer.ref.size = 0;
      writer.ref.max_size = 0;
      pic.ref.custom_ptr = writer.cast();
      pic.ref.writer = webPMemoryWritePtr;

      check(libwebp.WebPEncode(cfg, pic), 'Failed to encode WebP.');
      libwebp.WebPPictureFree(pic);

      final out = Uint8List.fromList(writer.ref.mem.asTypedList(writer.ref.size));
      libwebp.WebPMemoryWriterClear(writer);
      return out;
    });
  }
}

class WebPImageFramesIterable extends Iterable<WebPFrame> {
  final WebPImage _image;

  WebPImageFramesIterable(this._image);

  @override
  Iterator<WebPFrame> get iterator => WebPImageFramesIterator(_image);

  @override
  int get length => _image.info.frameCount;
}

class WebPImageFramesIterator implements Iterator<WebPFrame> {
  final WebPImage _image;
  int _index = -1;
  WebPFrame? _current;

  WebPImageFramesIterator(this._image);

  @override
  WebPFrame get current =>
      _current ?? (throw StateError('moveNext not called / iteration ended.'));

  @override
  bool moveNext() {
    final int next = _index + 1;
    if (next >= _image.info.frameCount) {
      _current = null;
      return false;
    }
    _index = next;
    final Pointer<Uint8> rgba = _image.ensureDecodedAt(next);
    _current = WebPFrame._(
      image: _image,
      metadata: _image.framesMetadata[next],
      rgba: rgba,
    );
    return true;
  }
}

enum WebPPreset {
  default_(bindings.WebPPreset.WEBP_PRESET_DEFAULT),
  picture(bindings.WebPPreset.WEBP_PRESET_PICTURE),
  photo(bindings.WebPPreset.WEBP_PRESET_PHOTO),
  drawing(bindings.WebPPreset.WEBP_PRESET_DRAWING),
  icon(bindings.WebPPreset.WEBP_PRESET_ICON),
  text(bindings.WebPPreset.WEBP_PRESET_TEXT);

  final int value;

  const WebPPreset(this.value);
}

class _WebPAnimDecoder implements Finalizable {
  final Pointer<bindings.WebPAnimDecoder> ptr;
  final WebPAnimDecoderOptions options;
  final WebPData webpData;
  final bool _disposed = false;

  factory _WebPAnimDecoder(
    FfiByteData data, {
    WebPAnimDecoderOptions? options,
  }) {
    final webpData = WebPData(freeInnerBuffer: false)
      ..bytes = data.ptr
      ..size = data.size;

    final WebPAnimDecoderOptions opt = options ?? WebPAnimDecoderOptions();

    final Pointer<bindings.WebPAnimDecoder> dec = checkAlloc(libwebp.WebPAnimDecoderNewInternal(
      webpData.ptr,
      opt.ptr,
      bindings.WEBP_DEMUX_ABI_VERSION,
    ));

    final wrapper = _WebPAnimDecoder._(ptr: dec, webpData: webpData, options: opt);

    decoderFinalizer.attach(wrapper, dec, detach: wrapper);

    return wrapper;
  }

  _WebPAnimDecoder._({
    required this.ptr,
    required this.webpData,
    required this.options,
  });

  late final info = WebPAnimInfo.readFromAnimDecoder(ptr);

  bool getNext(Pointer<Pointer<Uint8>> frame, Pointer<Int> timestamp) {
    if (_disposed) {
      throw StateError('WebPImage already disposed');
    }
    return libwebp.WebPAnimDecoderGetNext(ptr, frame, timestamp) != 0;
  }

  void reset() {
    if (_disposed) {
      throw StateError('WebPImage already disposed');
    }

    libwebp.WebPAnimDecoderReset(ptr);
  }

  void free() {
    if (_disposed) {
      throw StateError('WebPImage already disposed');
    }
    libwebp.WebPAnimDecoderDelete(ptr);
    decoderFinalizer.detach(this);
  }
}

final class WebPAnimDecoderOptions implements Finalizable {
  final Pointer<bindings.WebPAnimDecoderOptions> ptr;
  bool _disposed = false;

  factory WebPAnimDecoderOptions({
    int colorMode = bindings.WEBP_CSP_MODE.MODE_RGBA,
    bool useThreads = false,
  }) {
    final opt = WebPAnimDecoderOptions._();
    check(
      libwebp.WebPAnimDecoderOptionsInitInternal(
        opt.ptr,
        bindings.WEBP_DEMUX_ABI_VERSION,
      ),
      'Failed to initialize WebPAnimDecoderOptions.',
    );
    opt.ptr.ref.color_mode = colorMode;
    opt.ptr.ref.use_threads = useThreads ? 1 : 0;
    return opt;
  }

  WebPAnimDecoderOptions._() : ptr = calloc<bindings.WebPAnimDecoderOptions>() {
    callocFinalizer.attach(this, ptr.cast(), detach: this);
  }

  void free() {
    if (_disposed) {
      throw StateError('WebPAnimDecoderOptions already disposed');
    }
    calloc.free(ptr);
    callocFinalizer.detach(this);
    _disposed = true;
  }
}

final class WebPAnimInfo extends CallocFinalizable<bindings.WebPAnimInfo> {
  WebPAnimInfo() : super(calloc<bindings.WebPAnimInfo>());

  int get canvasWidth => ptr.ref.canvas_width;
  int get canvasHeight => ptr.ref.canvas_height;
  int get loopCount => ptr.ref.loop_count;
  int get bgColor => ptr.ref.bgcolor;
  int get frameCount => ptr.ref.frame_count;

  static WebPAnimInfo readFromAnimDecoder(
    Pointer<bindings.WebPAnimDecoder> ptr,
  ) {
    final info = WebPAnimInfo();
    check(
      libwebp.WebPAnimDecoderGetInfo(ptr, info.ptr),
      'Failed to get WebPAnimInfo.',
    );
    return info;
  }
}
