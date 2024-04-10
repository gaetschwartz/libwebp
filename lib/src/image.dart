import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:libwebp/src/libwebp.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart' as bindings;
import 'package:libwebp/src/utils.dart';

export 'libwebp_generated_bindings.dart' show WebPAnimInfo;

typedef WebPDecoderFinalizable = ({
  Arena arena,
  Pointer<bindings.WebPAnimDecoder> decoder
});

class WebPImage implements Finalizable {
  static final _callocFinalizer = NativeFinalizer(calloc.nativeFree);

  final FfiByteData _data;
  final _WebPAnimDecoder _decoder;
  final Pointer<bindings.WebPAnimInfo> _infoPtr;

  factory WebPImage(Uint8List data) {
    final d = FfiByteData.fromTypedList(data);
    return WebPImage.native(d);
  }

  factory WebPImage.native(FfiByteData data) {
    final dec = _WebPAnimDecoder(data);
    final infoPtr = calloc<bindings.WebPAnimInfo>();

    final wrapper = WebPImage._(
      data: data,
      decoder: dec,
      infoPtr: infoPtr,
    );

    _callocFinalizer.attach(wrapper, infoPtr.cast(), detach: wrapper);

    return wrapper;
  }

  WebPImage._({
    required FfiByteData data,
    required _WebPAnimDecoder decoder,
    required Pointer<bindings.WebPAnimInfo> infoPtr,
  })  : _data = data,
        _decoder = decoder,
        _infoPtr = infoPtr;

  bindings.WebPAnimInfo get info {
    check(
      libwebp.WebPAnimDecoderGetInfo(_decoder.ptr, _infoPtr),
      'Failed to get WebPAnimInfo.',
    );
    return _infoPtr.ref;
  }

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
  static final _callocFinalizer = NativeFinalizer(calloc.nativeFree);
  final _WebPAnimDecoder _decoder;
  final Pointer<Pointer<Uint8>> _frame;
  final Pointer<Int> _ts;
  final Pointer<bindings.WebPAnimInfo> _infoPtr;

  factory WebPImageFramesIterator(WebPImage image) {
    final dec = _WebPAnimDecoder(image._data);

    final frame = calloc<Pointer<Uint8>>();
    final ts = calloc<Int>();
    final infoPtr = calloc<bindings.WebPAnimInfo>();

    final wrapper = WebPImageFramesIterator._(
      decoder: dec,
      frame: frame,
      ts: ts,
      infoPtr: infoPtr,
    );

    _callocFinalizer.attach(wrapper, frame.cast(), detach: wrapper);
    _callocFinalizer.attach(wrapper, ts.cast(), detach: wrapper);
    _callocFinalizer.attach(wrapper, infoPtr.cast(), detach: wrapper);

    return wrapper;
  }

  WebPImageFramesIterator._({
    required _WebPAnimDecoder decoder,
    required Pointer<Pointer<Uint8>> frame,
    required Pointer<Int> ts,
    required Pointer<bindings.WebPAnimInfo> infoPtr,
  })  : _decoder = decoder,
        _frame = frame,
        _ts = ts,
        _infoPtr = infoPtr;

  WebPFrame? _current;

  @override
  WebPFrame get current {
    if (_current == null) {
      throw StateError('No current frame.');
    }
    return _current!;
  }

  late final _info = () {
    check(
      libwebp.WebPAnimDecoderGetInfo(_decoder.ptr, _infoPtr),
      'Failed to get WebPAnimInfo.',
    );
    return _infoPtr.ref;
  }();

  @override
  bool moveNext() {
    if (!libwebp.WebPAnimDecoderGetNext(_decoder.ptr, _frame, _ts).asCBoolean) {
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
  static final _webPAnimDecoderDeletePtr =
      rawBindings.lookup<NativeFunction<bindings.NativeWebPAnimDecoderDelete>>(
    'WebPAnimDecoderDelete',
  );

  static final _decodeFinalizer =
      NativeFinalizer(_webPAnimDecoderDeletePtr.cast());

  final Pointer<bindings.WebPAnimDecoder> ptr;

  factory _WebPAnimDecoder(
    FfiByteData data, {
    int colorMode = bindings.WEBP_CSP_MODE.MODE_RGBA,
  }) {
    final dec = using((a) {
      final webpData = a<bindings.WebPData>()
        ..ref.bytes = data.ptr
        ..ref.size = data.size;

      final opt = a<bindings.WebPAnimDecoderOptions>();
      check(
        libwebp.WebPAnimDecoderOptionsInitInternal(
          opt,
          bindings.WEBP_DEMUX_ABI_VERSION,
        ),
        'Failed to initialize WebPAnimDecoderOptions.',
      );
      opt.ref.color_mode = colorMode;
      opt.ref.use_threads = 1;

      return checkAlloc(libwebp.WebPAnimDecoderNewInternal(
        webpData,
        opt,
        bindings.WEBP_DEMUX_ABI_VERSION,
      ));
    });

    final wrapper = _WebPAnimDecoder._(ptr: dec);

    _decodeFinalizer.attach(wrapper, dec.cast(), detach: wrapper);

    return wrapper;
  }

  _WebPAnimDecoder._({required this.ptr});
}
