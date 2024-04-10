import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:libwebp/src/finalizers.dart';
import 'package:libwebp/src/libwebp.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart' as bindings;
import 'package:libwebp/src/utils.dart';

export 'libwebp_generated_bindings.dart' show WebPAnimInfo;

typedef WebPDecoderFinalizable = ({
  Arena arena,
  Pointer<bindings.WebPAnimDecoder> decoder
});

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

  bindings.WebPAnimInfo get info => _decoder.info;

  /// An iterable of frames in the WebP image. Frames data is only valid before
  /// the next frame is decoded.
  Iterable<WebPFrame> get frames => WebPImageFramesIterable(this);

  late final timings =
      ListWebPAnimationTiming(frames.map((e) => e.duration).toList());

  double get fps => 1000 * info.frame_count / timings.value.last.inMilliseconds;

  Duration get averageFrameDuration =>
      timings.value.last ~/ timings.value.length;
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
        final pic = alloc<bindings.WebPPicture>();
        check(
          libwebp.WebPPictureInitInternal(
              pic, bindings.WEBP_ENCODER_ABI_VERSION),
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

        final cfg = alloc<bindings.WebPConfig>();
        check(
          libwebp.WebPConfigInitInternal(
            cfg,
            bindings.WebPPreset.WEBP_PRESET_DEFAULT,
            quality,
            bindings.WEBP_ENCODER_ABI_VERSION,
          ),
          'Failed to init WebPConfig.',
        );
        final writer = alloc<bindings.WebPMemoryWriter>();
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

        final out =
            Uint8List.fromList(writer.ref.mem.asTypedList(writer.ref.size));
        libwebp.WebPMemoryWriterClear(writer);
        return out;
      });
    } else {
      return using((alloc) {
        final out = alloc<Pointer<Uint8>>();
        final size = check(
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
    final dur = switch (_current) {
      final c? => Duration(milliseconds: _ts.value - c.timestamp),
      null => Duration(milliseconds: _ts.value),
    };
    _current = WebPFrame(
      timestamp: _ts.value,
      duration: dur,
      data: _frame.value,
      width: _info.canvas_width,
      height: _info.canvas_height,
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
  final Pointer<bindings.WebPAnimInfo> _infoPtr;
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

    final opt = options ?? WebPAnimDecoderOptions();

    final dec = checkAlloc(libwebp.WebPAnimDecoderNewInternal(
      webpData.ptr,
      opt.ptr,
      bindings.WEBP_DEMUX_ABI_VERSION,
    ));

    final wrapper =
        _WebPAnimDecoder._(ptr: dec, webpData: webpData, options: opt);

    decoderFinalizer.attach(wrapper, dec, detach: wrapper);

    return wrapper;
  }

  _WebPAnimDecoder._({
    required this.ptr,
    required this.webpData,
    required this.options,
  }) : _infoPtr = calloc<bindings.WebPAnimInfo>() {
    callocFinalizer.attach(this, _infoPtr.cast(), detach: this);
  }

  bindings.WebPAnimInfo get info {
    if (_disposed) {
      throw StateError('WebPImage already disposed');
    }
    check(
      libwebp.WebPAnimDecoderGetInfo(ptr, _infoPtr),
      'Failed to get WebPAnimInfo.',
    );
    return _infoPtr.ref;
  }

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
    calloc.free(_infoPtr);
    libwebp.WebPAnimDecoderDelete(ptr);

    decoderFinalizer.detach(this);
    callocFinalizer.detach(this);
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
