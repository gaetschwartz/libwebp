import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:libwebp/src/finalizers.dart';
import 'package:libwebp/src/libwebp.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart' as bindings;
import 'package:libwebp/src/utils.dart';

typedef WebPDecoderFinalizable = ({Arena arena, Pointer<bindings.WebPAnimDecoder> decoder});

class WebPImage implements Finalizable {
  final FfiByteData _data;
  final _WebPAnimDecoder _decoder;

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

  /// An iterable of frames in the WebP image. Frames data is only valid before
  /// the next frame is decoded.
  Iterable<WebPFrame> get frames => WebPImageFramesIterable(this);
  Iterable<WebPIteratorFrame> get framesV2 => WebPImageFramesIterableV2(this);

  late final timings = ListWebPAnimationTiming(frames.map((e) => e.duration).toList());

  double get fps => 1000 * info.frameCount / timings.value.last.inMilliseconds;

  Duration get averageFrameDuration => timings.value.last ~/ timings.value.length;
}

class WebPFrame {
  final int timestamp;
  final Duration duration;
  final Pointer<Uint8> data;
  final int width;
  final int height;

  WebPFrame({
    required this.timestamp,
    required this.duration,
    required this.data,
    required this.width,
    required this.height,
  });

  Uint8List encode({
    double quality = 100,
    ({int width, int height})? targetDimensions,
  }) {
    if (targetDimensions case final dim?) {
      return using((alloc) {
        final Pointer<bindings.WebPPicture> pic = alloc<bindings.WebPPicture>();
        check(
          libwebp.WebPPictureInitInternal(pic, bindings.WEBP_ENCODER_ABI_VERSION),
          'Failed to init WebPPicture.',
        );
        pic.ref.use_argb = 1; // use ARGB
        pic.ref.width = width;
        pic.ref.height = height;
        check(
          libwebp.WebPPictureAlloc(pic),
          'Failed to allocate WebPPicture.',
        );

        check(
          libwebp.WebPPictureImportRGBA(pic, data, width * 4),
          'Failed to import frame to WebPPicture.',
        );

        check(
          libwebp.WebPPictureRescale(pic, dim.width, dim.height),
          'Failed to rescale frame.',
        );

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

        check(
          libwebp.WebPEncode(cfg, pic),
          'Failed to encode WebP.',
        );
        libwebp.WebPPictureFree(pic);

        final out = Uint8List.fromList(writer.ref.mem.asTypedList(writer.ref.size));
        libwebp.WebPMemoryWriterClear(writer);
        return out;
      });
    } else {
      return using((alloc) {
        final Pointer<Pointer<Uint8>> out = alloc<Pointer<Uint8>>();
        final int size = check(
          libwebp.WebPEncodeRGBA(
            data,
            width,
            height,
            width * 4,
            quality,
            out,
          ),
          'Failed to encode WebP.',
        );

        return Uint8List.fromList(out.value.asTypedList(size));
      });
    }
  }
}

class WebPImageFramesIterableV2 extends Iterable<WebPIteratorFrame> {
  final WebPImage _image;

  WebPImageFramesIterableV2(this._image);

  @override
  Iterator<WebPIteratorFrame> get iterator => WebPImageFramesIteratorV2(_image);
}

class WebPImageFramesIteratorV2 implements Iterator<WebPIteratorFrame>, Finalizable {
  final Pointer<bindings.WebPIterator> _iter;
  final bool _hasFrameOne;

  factory WebPImageFramesIteratorV2(WebPImage image) {
    final Pointer<bindings.WebPDemuxer> demuxer = checkAlloc(
      libwebp.WebPAnimDecoderGetDemuxer(
        image._decoder.ptr,
      ),
      'Failed to create WebPDemux.',
    );
    final Pointer<bindings.WebPIterator> iter = calloc<bindings.WebPIterator>();

    final bool hasFrameOne = libwebp.WebPDemuxGetFrame(demuxer, 1, iter).asCBoolean;

    final wrapper = WebPImageFramesIteratorV2._(iter, hasFrameOne);

    iteratorFinalizer.attach(wrapper, iter, detach: wrapper);

    return wrapper;
  }

  WebPImageFramesIteratorV2._(this._iter, this._hasFrameOne);

  int _frameNum = 0;

  @override
  WebPIteratorFrame get current {
    if (_frameNum < 1) {
      throw StateError('No current frame.');
    }
    return WebPIteratorFrame(
      frameNum: _iter.ref.frame_num,
      duration: Duration(milliseconds: _iter.ref.duration),
      numFrames: _iter.ref.num_frames,
      xOffset: _iter.ref.x_offset,
      yOffset: _iter.ref.y_offset,
      dispose: WebPMuxAnimDispose.fromInt(_iter.ref.dispose_method),
      complete: _iter.ref.complete != 0,
      fragment: WebPData.view(Pointer.fromAddress(_iter.address)),
      hasAlpha: _iter.ref.has_alpha != 0,
      blend: WebPMuxAnimBlend.fromInt(_iter.ref.blend_method),
      width: _iter.ref.width,
      height: _iter.ref.height,
    );
  }

  @override
  bool moveNext() {
    if (!_hasFrameOne) {
      return false;
    }
    if (_frameNum == 0) {
      _frameNum++;
      return true;
    }
    if (libwebp.WebPDemuxNextFrame(_iter).asCBoolean) {
      _frameNum++;
      return true;
    } else {
      return false;
    }
  }
}

final class WebPIteratorFrame {
  final int frameNum;
  final int numFrames;
  final int xOffset;
  final int yOffset;
  final int width;
  final int height;
  final Duration duration;
  final WebPMuxAnimDispose dispose;
  final bool complete;
  final WebPData fragment;
  final bool hasAlpha;
  final WebPMuxAnimBlend blend;

  const WebPIteratorFrame({
    required this.frameNum,
    required this.numFrames,
    required this.xOffset,
    required this.yOffset,
    required this.width,
    required this.height,
    required this.duration,
    required this.dispose,
    required this.complete,
    required this.fragment,
    required this.hasAlpha,
    required this.blend,
  });
}

class WebPImageFramesIterable extends Iterable<WebPFrame> {
  final WebPImage _image;

  WebPImageFramesIterable(this._image);

  @override
  Iterator<WebPFrame> get iterator => WebPImageFramesIterator(_image);
}

class WebPImageFramesIterator implements Iterator<WebPFrame>, Finalizable {
  final _WebPAnimDecoder _decoder;
  final Pointer<Pointer<Uint8>> _frame;
  final Pointer<Int> _ts;

  factory WebPImageFramesIterator(WebPImage image) {
    final dec = _WebPAnimDecoder(image._data);

    return WebPImageFramesIterator._(decoder: dec);
  }

  WebPImageFramesIterator._({
    required _WebPAnimDecoder decoder,
  })  : _decoder = decoder,
        _frame = calloc<Pointer<Uint8>>(),
        _ts = calloc<Int>() {
    callocFinalizer.attach(this, _frame.cast(), detach: this);
    callocFinalizer.attach(this, _ts.cast(), detach: this);
  }

  WebPFrame? _current;

  @override
  WebPFrame get current {
    if (_current == null) {
      throw StateError('No current frame.');
    }
    return _current!;
  }

  late final _info = _decoder.info;

  @override
  bool moveNext() {
    if (!_decoder.getNext(_frame, _ts)) {
      return false;
    }
    final Duration dur = switch (_current) {
      final WebPFrame c? => Duration(milliseconds: _ts.value - c.timestamp),
      null => Duration(milliseconds: _ts.value),
    };
    _current = WebPFrame(
      timestamp: _ts.value,
      duration: dur,
      data: _frame.value,
      width: _info.canvasWidth,
      height: _info.canvasHeight,
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
