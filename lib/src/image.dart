import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:libwebp/libwebp_generated_bindings.dart' as bindings;
import 'package:libwebp/src/utils.dart';

class WebpImage {
  final Uint8Data _data;
  final Allocator _alloc;
  final Pointer<bindings.WebPAnimDecoder> _decoder;

  late final Pointer<bindings.WebPAnimInfo> _infoPtr =
      _alloc<bindings.WebPAnimInfo>();

  static final Finalizer<Arena> _finalizer = Finalizer<Arena>((data) {
    data.releaseAll();
    print('released WebpImage.');
  });

  factory WebpImage(Uint8List data) {
    final alloc = Arena(calloc);
    final d = alloc.uint8Array(data.length);
    d.asList.setAll(0, data);
    final webpImage = WebpImage._(
      data: d,
      alloc: alloc,
      decoder: _animDecoder(alloc, d),
    );
    _finalizer.attach(webpImage, alloc, detach: webpImage);
    return webpImage;
  }

  WebpImage._(
      {required Uint8Data data,
      required Allocator alloc,
      required Pointer<bindings.WebPAnimDecoder> decoder})
      : _data = data,
        _alloc = alloc,
        _decoder = decoder;

  bindings.WebPAnimInfo get info {
    if (libwebp.WebPAnimDecoderGetInfo(_decoder, _infoPtr) == 0) {
      throw LibWebpException('Failed to get info.');
    }
    return _infoPtr.ref;
  }

  Iterable<WebpFrame> get frames => WebpImageFramesIterable._(
        _alloc,
        _animDecoder(_alloc, _data),
        info,
      );

  double get fps => 1000 * info.frame_count / frames.last.timestamp;
}

class WebpFrame {
  final int timestamp;
  final Pointer<Pointer<Uint8>> _data;
  final int width;
  final int height;

  WebpFrame({
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

class WebpImageFramesIterable extends Iterable<WebpFrame> {
  final Pointer<bindings.WebPAnimDecoder> _decoder;
  final Allocator _alloc;
  final bindings.WebPAnimInfo _info;

  WebpImageFramesIterable._(this._alloc, this._decoder, this._info);

  @override
  Iterator<WebpFrame> get iterator =>
      WebpImageFramesIterator._(_alloc, _decoder, _info);
}

class WebpImageFramesIterator implements Iterator<WebpFrame> {
  WebpFrame? _current;

  final Pointer<bindings.WebPAnimDecoder> _decoder;
  final Allocator _alloc;
  final bindings.WebPAnimInfo _info;

  WebpImageFramesIterator._(this._alloc, this._decoder, this._info);

  @override
  WebpFrame get current => _current!;

  @override
  bool moveNext() {
    final frame = _alloc<Pointer<Uint8>>();
    final ms = _alloc<Int>();
    if (libwebp.WebPAnimDecoderGetNext(_decoder, frame, ms) == 0) {
      return false;
    }
    _current = WebpFrame(
      timestamp: ms.value,
      data: frame,
      width: _info.canvas_width,
      height: _info.canvas_height,
    );
    return true;
  }
}

enum WebpPreset {
  default_(bindings.WebPPreset.WEBP_PRESET_DEFAULT),
  picture(bindings.WebPPreset.WEBP_PRESET_PICTURE),
  photo(bindings.WebPPreset.WEBP_PRESET_PHOTO),
  drawing(bindings.WebPPreset.WEBP_PRESET_DRAWING),
  icon(bindings.WebPPreset.WEBP_PRESET_ICON),
  text(bindings.WebPPreset.WEBP_PRESET_TEXT);

  final int value;

  const WebpPreset(this.value);
}

class WebPConfig {
  final Pointer<bindings.WebPConfig> _config;

  static final Finalizer<Arena> _finalizer =
      Finalizer<Arena>((a) => a.releaseAll());

  factory WebPConfig({
    WebpPreset preset = WebpPreset.default_,
    double quality = 75.0,
  }) {
    final alloc = Arena(calloc);

    final cfg = alloc<bindings.WebPConfig>();
    if (libwebp.WebPConfigInitInternal(
          cfg,
          preset.value,
          quality,
          bindings.WEBP_ENCODER_ABI_VERSION,
        ) ==
        0) {
      throw LibWebpException('Failed to init WebPConfig.');
    }

    final webpConfig = WebPConfig._(config: cfg);

    _finalizer.attach(webpConfig, alloc, detach: webpConfig);

    return webpConfig;
  }

  WebPConfig._({
    required Pointer<bindings.WebPConfig> config,
  }) : _config = config;
}

class WebpEncoder {
  static final Finalizer<Arena> _finalizer =
      Finalizer<Arena>((a) => a.releaseAll());
  final Allocator _alloc;
  final Pointer<bindings.WebPAnimEncoder> _encoder;
  final WebPConfig? config;
  final int width;
  final int height;
  final double fps;
  int _timestamp;
  int _frames = 0;

  int get currentTimestamp => _timestamp;

  int get frameDuration => 1000 ~/ fps;

  factory WebpEncoder({
    required int width,
    required int height,
    required double fps,
    WebPConfig? config,
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
    cfg.ref.verbose = 1;

    final encoder = libwebp.WebPAnimEncoderNewInternal(
      width,
      height,
      cfg,
      bindings.WEBP_MUX_ABI_VERSION,
    );
    if (encoder == nullptr) {
      throw LibWebpException('Failed to create WebPAnimEncoder.');
    }

    final webpEncoder = WebpEncoder._(
      alloc: alloc,
      encoder: encoder,
      config: config,
      width: width,
      height: height,
      fps: fps,
    );
    _finalizer.attach(webpEncoder, alloc, detach: webpEncoder);
    return webpEncoder;
  }

  WebpEncoder._({
    required Allocator alloc,
    required Pointer<bindings.WebPAnimEncoder> encoder,
    required this.config,
    required this.width,
    required this.height,
    required this.fps,
  })  : _alloc = alloc,
        _encoder = encoder,
        _timestamp = 1000 ~/ fps;

  void add(WebpImage image, {Duration delay = Duration.zero}) {
    _timestamp += delay.inMilliseconds;

    final info = image.info;

    print("Adding image with ${info.frame_count} frames");

    for (final frame in image.frames) {
      print('  Adding frame $_frames at $_timestamp ms');
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
        config != null ? config!._config : nullptr,
      );

      if (added == 0) {
        final str = libwebp.WebPAnimEncoderGetError(_encoder) as Pointer<Utf8>;
        throw LibWebpException(
          'Failed to add frame $_frames to encoder. (${VP8StatusCode.fromValue(pic.ref.error_code)}, ${str.toDartString()})',
        );
      } else {
        _timestamp += frameDuration;
        _frames++;
      }

      libwebp.WebPPictureFree(pic);
    }
  }

  Duration get duration => Duration(milliseconds: _timestamp);

  int get frameCount => _frames;

  Uint8List encode() {
    // add a blank frame to make sure the last frame is included
    print('Adding blank frame at $_timestamp ms');
    _check(
      libwebp.WebPAnimEncoderAdd(
        _encoder,
        nullptr,
        _timestamp,
        config != null ? config!._config : nullptr,
      ),
      'Failed to add blank frame to encoder.',
    );

    final data = _alloc<bindings.WebPData>();

    final res = libwebp.WebPAnimEncoderAssemble(_encoder, data);
    if (res == 0) {
      throw LibWebpException('Failed to assemble WebPData.');
    }

    final uint8list = data.toList();
    libwebp.WebPAnimEncoderDelete(_encoder);
    return uint8list;
  }
}

void _check(int res, [String? message]) {
  if (res == 0) {
    throw LibWebpException(message ?? 'Failed with error code $res.');
  }
}

Pointer<bindings.WebPAnimDecoder> _animDecoder(Allocator a, Uint8Data data) {
  final webpData = a<bindings.WebPData>();
  webpData.ref.bytes = data.ptr;
  webpData.ref.size = data.length;

  final opt = a<bindings.WebPAnimDecoderOptions>();
  libwebp.WebPAnimDecoderOptionsInitInternal(
      opt, bindings.WEBP_DEMUX_ABI_VERSION);
  opt.ref.color_mode = bindings.WEBP_CSP_MODE.MODE_RGBA;

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

extension WebpDataX on Pointer<bindings.WebPData> {
  Uint8List toList() => Uint8List.fromList(ref.bytes.asTypedList(ref.size));
}
