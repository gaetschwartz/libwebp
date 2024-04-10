import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:libwebp/src/libwebp.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart' as bindings;
import 'package:libwebp/src/utils.dart';
import 'package:logging/logging.dart';

export 'libwebp_generated_bindings.dart' show WebPAnimInfo;

typedef WebPDecoderFinalizable = ({
  Arena arena,
  Pointer<bindings.WebPAnimDecoder> decoder
});

class WebPImage {
  final FfiByteData _data;
  final Allocator _alloc;
  final Pointer<bindings.WebPAnimDecoder> _decoder;

  late final _infoPtr = _alloc<bindings.WebPAnimInfo>();

  static final _logger = Logger('WebPImage');
  static final _finalizer = Finalizer<WebPDecoderFinalizable>((data) {
    _logger.finest('Finalizing WebPImage.');
    data.arena.releaseAll();
    libwebp.WebPAnimDecoderDelete(data.decoder);
  });

  factory WebPImage(Uint8List data) {
    final arena = Arena(calloc);

    final d = FfiByteData.fromTypedList(data, arena);
    final dec = _animDecoder(arena, d);
    final wrapper = WebPImage._(data: d, alloc: arena, decoder: dec);
    _finalizer.attach(
      wrapper,
      (arena: arena, decoder: dec),
      detach: wrapper,
    );
    return wrapper;
  }

  factory WebPImage.native(FfiByteData data) {
    final arena = Arena(calloc);
    final dec = _animDecoder(arena, data);
    final wrapper = WebPImage._(data: data, alloc: arena, decoder: dec);
    _finalizer.attach(
      wrapper,
      (arena: arena, decoder: dec),
      detach: wrapper,
    );
    return wrapper;
  }

  WebPImage._({
    required FfiByteData data,
    required Allocator alloc,
    required Pointer<bindings.WebPAnimDecoder> decoder,
  })  : _data = data,
        _alloc = alloc,
        _decoder = decoder;

  bindings.WebPAnimInfo get info {
    check(
      libwebp.WebPAnimDecoderGetInfo(_decoder, _infoPtr),
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

class WebPImageFramesIterator implements Iterator<WebPFrame> {
  static final _logger = Logger('WebPImageFramesIterator');
  static final _finalizer = Finalizer<WebPDecoderFinalizable>(
    (data) {
      _logger.finest('Finalizing WebPImageFramesIterator.');
      data.arena.releaseAll();
      libwebp.WebPAnimDecoderDelete(data.decoder);
    },
  );

  final Pointer<bindings.WebPAnimDecoder> _decoder;
  final Allocator _alloc;

  factory WebPImageFramesIterator(WebPImage image) {
    final arena = Arena(calloc);
    final dec = _animDecoder(
      arena,
      image._data,
      colorMode: bindings.WEBP_CSP_MODE.MODE_RGBA,
    );
    final wrapper = WebPImageFramesIterator._(arena, dec);
    _finalizer.attach(wrapper, (arena: arena, decoder: dec), detach: wrapper);
    return wrapper;
  }

  WebPImageFramesIterator._(this._alloc, this._decoder);

  WebPFrame? _current;

  @override
  WebPFrame get current {
    if (_current == null) {
      throw StateError('No current frame.');
    }
    return _current!;
  }

  late final _info = () {
    final infoPtr = _alloc<bindings.WebPAnimInfo>();
    check(
      libwebp.WebPAnimDecoderGetInfo(_decoder, infoPtr),
      'Failed to get WebPAnimInfo.',
    );
    final ref = infoPtr.ref;
    _alloc.free(infoPtr);
    return ref;
  }();

  late final frame = _alloc<Pointer<Uint8>>();
  late final ts = _alloc<Int>();

  @override
  bool moveNext() {
    if (!libwebp.WebPAnimDecoderGetNext(_decoder, frame, ts).asCBoolean) {
      return false;
    }
    final dur = switch (_current) {
      final c? => Duration(milliseconds: ts.value - c.timestamp),
      null => Duration(milliseconds: ts.value),
    };
    _current = WebPFrame(
      timestamp: ts.value,
      duration: dur,
      data: frame.value,
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

Pointer<bindings.WebPAnimDecoder> _animDecoder(
  Allocator alloc,
  FfiByteData data, {
  int colorMode = bindings.WEBP_CSP_MODE.MODE_RGBA,
}) {
  final webpData = alloc<bindings.WebPData>()
    ..ref.bytes = data.ptr
    ..ref.size = data.size;

  final opt = alloc<bindings.WebPAnimDecoderOptions>();
  check(
    libwebp.WebPAnimDecoderOptionsInitInternal(
      opt,
      bindings.WEBP_DEMUX_ABI_VERSION,
    ),
    'Failed to initialize WebPAnimDecoderOptions.',
  );
  opt.ref.color_mode = colorMode;
  opt.ref.use_threads = 1;

  final decoder = checkAlloc(libwebp.WebPAnimDecoderNewInternal(
    webpData,
    opt,
    bindings.WEBP_DEMUX_ABI_VERSION,
  ));

  return decoder;
}
