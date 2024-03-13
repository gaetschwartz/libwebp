import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:libwebp/libwebp_generated_bindings.dart' as bindings;
import 'package:libwebp/src/utils.dart';
import 'package:logging/logging.dart';

typedef WebPDecoderFinalizable = ({
  Arena arena,
  Pointer<bindings.WebPAnimDecoder> decoder
});

class WebPImage {
  final FfiByteData _data;
  final Allocator _alloc;
  final Pointer<bindings.WebPAnimDecoder> _decoder;

  late final _infoPtr = _alloc<bindings.WebPAnimInfo>();

  static final _finalizer = Finalizer<WebPDecoderFinalizable>((data) {
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

  WebPImage._({
    required FfiByteData data,
    required Allocator alloc,
    required Pointer<bindings.WebPAnimDecoder> decoder,
  })  : _data = data,
        _alloc = alloc,
        _decoder = decoder;

  bindings.WebPAnimInfo get info {
    if (libwebp.WebPAnimDecoderGetInfo(_decoder, _infoPtr) == 0) {
      throw LibWebpException('Failed to get info.');
    }
    return _infoPtr.ref;
  }

  Iterable<WebPFrame> get frames => WebPImageFramesIterable(this);

  double get fps => 1000 * info.frame_count / frames.last.timestamp;

  int get averageFrameDuration => frames.last.timestamp ~/ info.frame_count;
}

class WebPFrame {
  final int timestamp;
  final Pointer<Pointer<Uint8>> _data;
  final int width;
  final int height;

  WebPFrame({
    required this.timestamp,
    required Pointer<Pointer<Uint8>> data,
    required this.width,
    required this.height,
  }) : _data = data;

  Uint8List encode({
    double quality = 100,
    int? width,
    int? height,
  }) =>
      using((Arena alloc) {
        final w = width ?? this.width;
        final h = height ?? this.height;
        final out = alloc<Pointer<Uint8>>();
        final size = libwebp.WebPEncodeRGBA(
          _data.value,
          w,
          h,
          w * 4,
          quality,
          out,
        );
        if (size == 0) {
          throw LibWebpException('Failed to encode frame.');
        }
        return Uint8List.fromList(out.value.asTypedList(size));
      });
}

class WebPImageFramesIterable extends Iterable<WebPFrame> {
  final WebPImage _image;

  WebPImageFramesIterable(this._image);

  @override
  Iterator<WebPFrame> get iterator => WebPImageFramesIterator(_image);
}

class WebPImageFramesIterator implements Iterator<WebPFrame> {
  WebPFrame? _current;

  static final _finalizer = Finalizer<Arena>(
    (data) => data.releaseAll(),
  );

  final WebPImage _image;
  final Pointer<bindings.WebPAnimDecoder> _decoder;
  final Allocator _alloc;

  WebPImageFramesIterator._(this._image, this._alloc)
      : _decoder = _animDecoder(calloc, _image._data);

  factory WebPImageFramesIterator(WebPImage image) {
    final alloc = Arena(calloc);
    final iterator = WebPImageFramesIterator._(image, alloc);
    _finalizer.attach(iterator, alloc, detach: iterator);
    return iterator;
  }

  @override
  WebPFrame get current => _current!;

  late final _info = _image.info;

  @override
  bool moveNext() {
    final frame = _alloc<Pointer<Uint8>>();
    final ms = _alloc<Int>();
    if (libwebp.WebPAnimDecoderGetNext(_decoder, frame, ms) == 0) {
      return false;
    }
    _current = WebPFrame(
      timestamp: ms.value,
      data: frame,
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

class WebPConfig {
  const WebPConfig.ffi(this._ffi);

  final Pointer<bindings.WebPConfig> _ffi;

  static final _finalizer = Finalizer<Arena>((a) => a.releaseAll());

  factory WebPConfig({
    WebPPreset preset = WebPPreset.default_,
    double quality = 75.0,
    bool lossless = false,
    bool multiThreading = true,
  }) {
    final alloc = Arena(calloc);

    final cfg = alloc<bindings.WebPConfig>();
    _check(
      libwebp.WebPConfigInitInternal(
        cfg,
        preset.value,
        quality,
        bindings.WEBP_ENCODER_ABI_VERSION,
      ),
      'Failed to init WebPConfig.',
    );
    cfg.ref.lossless = lossless ? 1 : 0;
    cfg.ref.thread_level = multiThreading ? 1 : 0;

    final webpConfig = WebPConfig.ffi(cfg);

    _finalizer.attach(webpConfig, alloc, detach: webpConfig);

    return webpConfig;
  }

  bindings.WebPConfig get ref => _ffi.ref;
}

typedef WebPEncoderFinalizable = ({
  Arena arena,
  Pointer<bindings.WebPAnimEncoder> encoder
});

class WebPAnimEncoder {
  static final _finalizer = Finalizer<WebPEncoderFinalizable>((a) {
    a.arena.releaseAll();
    libwebp.WebPAnimEncoderDelete(a.encoder);
  });
  final Allocator _alloc;
  final Pointer<bindings.WebPAnimEncoder> _encoder;
  final WebPConfig? config;
  final int width;
  final int height;
  final WebPAnimationTiming timing;
  final bool verbose;
  final Logger? _logger;
  int _timestamp;
  int _frames = 0;

  int get currentTimestamp => _timestamp;

  factory WebPAnimEncoder({
    required int width,
    required int height,
    required WebPAnimationTiming timing,
    WebPConfig? config,
    bool verbose = false,
  }) {
    final alloc = Arena(calloc);

    final cfg = alloc<bindings.WebPAnimEncoderOptions>();
    _check(
      libwebp.WebPAnimEncoderOptionsInitInternal(
        cfg,
        bindings.WEBP_MUX_ABI_VERSION,
      ),
      'Failed to init WebPAnimEncoderOptions.',
    );
    cfg.ref.anim_params.loop_count = 0;
    cfg.ref.anim_params.bgcolor = 0;
    cfg.ref.verbose = verbose ? 1 : 0;

    final encoder = libwebp.WebPAnimEncoderNewInternal(
      width,
      height,
      cfg,
      bindings.WEBP_MUX_ABI_VERSION,
    );
    if (encoder == nullptr) {
      throw LibWebpException('Failed to create WebPAnimEncoder.');
    }

    final wrapper = WebPAnimEncoder._(
      alloc: alloc,
      encoder: encoder,
      config: config,
      width: width,
      height: height,
      timing: timing,
      verbose: verbose,
    );
    _finalizer.attach(
      wrapper,
      (arena: alloc, encoder: encoder),
      detach: wrapper,
    );
    return wrapper;
  }

  WebPAnimEncoder._({
    required Allocator alloc,
    required Pointer<bindings.WebPAnimEncoder> encoder,
    required this.config,
    required this.width,
    required this.height,
    required this.timing,
    required this.verbose,
  })  : _alloc = alloc,
        _encoder = encoder,
        _timestamp = timing.value,
        _logger = verbose ? Logger('WebpEncoder') : null;

  void _log(String message) {
    _logger?.fine(message);
  }

  void add(WebPImage image, {Duration delay = Duration.zero}) {
    _timestamp += delay.inMilliseconds;

    final info = image.info;

    _log("Adding image with ${info.frame_count} frames");

    for (final frame in image.frames) {
      _log('  Adding frame $_frames at $_timestamp ms');
      final pic = _alloc<bindings.WebPPicture>();
      _check(
        libwebp.WebPPictureInitInternal(pic, bindings.WEBP_ENCODER_ABI_VERSION),
        'Failed to init WebPPicture.',
      );
      pic.ref.use_argb = 1;
      pic.ref.width = info.canvas_width;
      pic.ref.height = info.canvas_height;

      _check(
        libwebp.WebPPictureAlloc(pic),
        'Failed to allocate WebPPicture.',
      );

      _check(
        libwebp.WebPPictureImportRGBA(
          pic,
          frame._data.value,
          info.canvas_width * 4,
        ),
        'Failed to import RGBA data.',
      );

      _check(
        libwebp.WebPPictureRescale(
          pic,
          width,
          height,
        ),
        'Failed to rescale WebPPicture.',
      );

      final added = libwebp.WebPAnimEncoderAdd(
        _encoder,
        pic,
        _timestamp,
        config.ptr,
      );

      if (added == 0) {
        throw LibWebPAnimEncoderException.of(
          _encoder,
          'Failed to add frame $_frames to encoder',
        );
      } else {
        _timestamp += timing.value;
        _frames++;
      }

      libwebp.WebPPictureFree(pic);
    }
  }

  Duration get duration => Duration(milliseconds: _timestamp);

  int get frameCount => _frames;

  Uint8List assemble() {
    // add a blank frame to make sure the last frame is included
    _log('Adding blank frame at $_timestamp ms');
    _check(
      libwebp.WebPAnimEncoderAdd(
        _encoder,
        nullptr,
        _timestamp,
        config.ptr,
      ),
      'Failed to add blank frame to encoder.',
    );

    final data = _alloc<bindings.WebPData>();

    final res = libwebp.WebPAnimEncoderAssemble(_encoder, data);
    if (res == 0) {
      throw LibWebPAnimEncoderException.of(
        _encoder,
        'Failed to assemble WebP.',
      );
    }
    libwebp.WebPAnimEncoderDelete(_encoder);

    return data.ref.bytes.asTypedList(data.ref.size);
  }
}

void _check(int res, [String? message]) {
  if (res == 0) {
    throw LibWebpException(message ?? 'Failed with error code $res.');
  }
}

Pointer<bindings.WebPAnimDecoder> _animDecoder(
  Allocator alloc,
  FfiByteData data,
) {
  final webpData = data.toWebPData(alloc);

  final opt = alloc<bindings.WebPAnimDecoderOptions>();
  libwebp.WebPAnimDecoderOptionsInitInternal(
    opt,
    bindings.WEBP_DEMUX_ABI_VERSION,
  );
  opt.ref.color_mode = bindings.WEBP_CSP_MODE.MODE_RGBA;
  opt.ref.use_threads = 1;

  final decoder = libwebp.WebPAnimDecoderNewInternal(
    webpData,
    opt,
    bindings.WEBP_DEMUX_ABI_VERSION,
  );
  if (decoder == nullptr) {
    throw LibWebpException('Failed to create WebPAnimDecoder.');
  }

  return decoder;
}

extension on WebPConfig? {
  Pointer<bindings.WebPConfig> get ptr => this?._ffi ?? nullptr;
}

class WebPAnimationTiming {
  final int value;
  const WebPAnimationTiming(this.value);

  WebPAnimationTiming.fps(double fps) : value = 1000 ~/ fps;
}
