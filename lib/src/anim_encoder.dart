import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart' as bindings;
import 'package:libwebp/src/utils.dart';
import 'package:logging/logging.dart';

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
  final WebPAnimEncoderOptions options;
  final Logger? _logger;
  int _timestamp;
  int _frames = 0;

  int get currentTimestamp => _timestamp;

  factory WebPAnimEncoder({
    required int width,
    required int height,
    required WebPAnimationTiming timing,
    WebPConfig? config,
    WebPAnimEncoderOptions options = const WebPAnimEncoderOptions(),
  }) {
    final alloc = Arena(calloc);

    final opts = options.toNative(alloc);

    final encoder = libwebp.WebPAnimEncoderNewInternal(
      width,
      height,
      opts,
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
      options: options,
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
    required this.options,
  })  : _alloc = alloc,
        _encoder = encoder,
        _timestamp = timing.value,
        _logger = options.verbose ? Logger('WebpEncoder') : null;

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
      check(
        libwebp.WebPPictureInitInternal(pic, bindings.WEBP_ENCODER_ABI_VERSION),
        'Failed to init WebPPicture.',
      );
      pic.ref.use_argb = 1;
      pic.ref.width = info.canvas_width;
      pic.ref.height = info.canvas_height;

      check(
        libwebp.WebPPictureAlloc(pic),
        'Failed to allocate WebPPicture.',
      );

      check(
        libwebp.WebPPictureImportRGBA(
          pic,
          frame.data,
          info.canvas_width * 4,
        ),
        'Failed to import RGBA data.',
      );

      check(
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
    check(
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

final class WebPAnimEncoderOptions {
  /// Animation parameters.
  final WebPMuxAnimParams animParams;

  /// If true, minimize the output size (slow). Implicitly
  /// disables key-frame insertion.
  final bool minimizeSize;

  /// Minimum and maximum distance between consecutive key
  /// frames in the output. The library may insert some key
  /// frames as needed to satisfy this criteria.
  /// Note that these conditions should hold: kmax > kmin
  /// and kmin >= kmax / 2 + 1. Also, if kmax <= 0, then
  /// key-frame insertion is disabled; and if kmax == 1,
  /// then all frames will be key-frames (kmin value does
  /// not matter for these special cases).
  final int kmin;
  final int kmax;

  /// If true, use mixed compression mode; may choose
  /// either lossy and lossless for each frame.

  final bool allowMixed;

  /// If true, print info and warning messages to stderr.

  final bool verbose;

  const WebPAnimEncoderOptions({
    this.animParams = const WebPMuxAnimParams(),
    this.minimizeSize = false,
    this.kmin = 0,
    this.kmax = 0,
    this.allowMixed = false,
    this.verbose = false,
  });

  Pointer<bindings.WebPAnimEncoderOptions> toNative(Allocator allocator) {
    final options = allocator<bindings.WebPAnimEncoderOptions>();
    options.ref.anim_params = animParams.toNative(allocator).ref;
    options.ref.minimize_size = minimizeSize ? 1 : 0;
    options.ref.kmin = kmin;
    options.ref.kmax = kmax;
    options.ref.allow_mixed = allowMixed ? 1 : 0;
    options.ref.verbose = verbose ? 1 : 0;
    return options;
  }
}

/// Animation parameters.
final class WebPMuxAnimParams {
  /// Background color of the canvas stored (in MSB order) as:
  /// Bits 00 to 07: Alpha.
  /// Bits 08 to 15: Red.
  /// Bits 16 to 23: Green.
  /// Bits 24 to 31: Blue.
  final int bgcolor;

  /// Number of times to repeat the animation [0 = infinite].
  final int loopCount;

  const WebPMuxAnimParams({
    this.bgcolor = 0,
    this.loopCount = 0,
  });

  Pointer<bindings.WebPMuxAnimParams> toNative(Allocator allocator) {
    final params = allocator<bindings.WebPMuxAnimParams>();
    params.ref.bgcolor = bgcolor;
    params.ref.loop_count = loopCount;
    return params;
  }
}

abstract class _WebpConfigBase {
  /// Lossless encoding (0=lossy(default), 1=lossless).
  int get lossless;
  set lossless(int value);

  /// between 0 and 100. For lossy, 0 gives the smallest
  /// size and 100 the largest. For lossless, this
  /// parameter is the amount of effort put into the
  /// compression: 0 is the fastest but gives larger
  /// files compared to the slowest, but best, 100.
  double get quality;
  set quality(double value);

  /// quality/speed trade-off (0=fast, 6=slower-better)
  int get method;
  set method(int value);

  /// Hint for image type (lossless only for now).
  int get imageHint;
  set imageHint(int value);

  /// if non-zero, set the desired target size in bytes.
  /// Takes precedence over the 'compression' parameter.
  int get targetSize;
  set targetSize(int value);

  /// if non-zero, specifies the minimal distortion to
  /// try to achieve. Takes precedence over target_size.
  double get targetPSNR;
  set targetPSNR(double value);

  /// maximum number of segments to use, in [1..4]
  int get segments;
  set segments(int value);

  /// Spatial Noise Shaping. 0=off, 100=maximum.
  int get snsStrength;
  set snsStrength(int value);

  /// range: [0 = off .. 100 = strongest]
  int get filterStrength;
  set filterStrength(int value);

  /// range: [0 = off .. 7 = least sharp]
  int get filterSharpness;
  set filterSharpness(int value);

  /// filtering type: 0 = simple, 1 = strong (only used
  /// if filter_strength > 0 or autofilter > 0)
  int get filterType;
  set filterType(int value);

  /// Auto adjust filter's strength [0 = off, 1 = on]
  int get autofilter;
  set autofilter(int value);

  /// Algorithm for encoding the alpha plane (0 = none,
  /// 1 = compressed with WebP lossless). Default is 1.
  int get alphaCompression;
  set alphaCompression(int value);

  /// Predictive filtering method for alpha plane.
  /// 0: none, 1: fast, 2: best. Default if 1.
  int get alphaFiltering;
  set alphaFiltering(int value);

  /// Between 0 (smallest size) and 100 (lossless).
  /// Default is 100.
  int get alphaQuality;
  set alphaQuality(int value);

  /// number of entropy-analysis passes (in [1..10]).
  int get pass;
  set pass(int value);

  /// if true, export the compressed picture back.
  /// In-loop filtering is not applied.
  int get showCompressed;
  set showCompressed(int value);

  /// preprocessing filter:
  /// 0=none, 1=segment-smooth, 2=pseudo-random dithering
  int get preprocessing;
  set preprocessing(int value);

  /// log2(number of token partitions) in [0..3]. Default
  /// is set to 0 for easier progressive decoding.
  int get partitions;
  set partitions(int value);

  /// quality degradation allowed to fit the 512k limit
  /// on prediction modes coding (0: no degradation,
  /// 100: maximum possible degradation).
  int get partitionLimit;
  set partitionLimit(int value);

  /// If true, compression parameters will be remapped
  /// to better match the expected output size from
  /// JPEG compression. Generally, the output size will
  /// be similar but the degradation will be lower.
  int get emulateJpegSize;
  set emulateJpegSize(int value);

  /// If non-zero, try and use multi-threaded encoding.
  int get threadLevel;
  set threadLevel(int value);

  /// If set, reduce memory usage (but increase CPU use).
  int get lowMemory;
  set lowMemory(int value);

  /// Near lossless encoding [0 = max loss .. 100 = off
  /// (default)].
  int get nearLossless;
  set nearLossless(int value);

  /// if non-zero, preserve the exact RGB values under
  /// transparent area. Otherwise, discard this invisible
  /// RGB information for better compression. The default
  /// value is 0.
  int get exact;
  set exact(int value);

  /// reserved for future lossless feature
  int get useDeltaPalette;
  set useDeltaPalette(int value);

  /// if needed, use sharp (and slow) RGB->YUV conversion
  int get useSharpYuv;
  set useSharpYuv(int value);

  /// minimum permissible quality factor
  int get qmin;
  set qmin(int value);

  /// maximum permissible quality factor
  int get qmax;
  set qmax(int value);
}

class WebPConfig implements _WebpConfigBase {
  const WebPConfig.native(this._ffi);

  final Pointer<bindings.WebPConfig> _ffi;

  static final _finalizer = Finalizer<Arena>((a) => a.releaseAll());

  factory WebPConfig({
    WebPPreset preset = WebPPreset.default_,
    double quality = 75.0,
  }) {
    final alloc = Arena(calloc);

    final cfg = alloc<bindings.WebPConfig>();
    check(
      libwebp.WebPConfigInitInternal(
        cfg,
        preset.value,
        quality,
        bindings.WEBP_ENCODER_ABI_VERSION,
      ),
      'Failed to init WebPConfig.',
    );

    final webpConfig = WebPConfig.native(cfg);

    _finalizer.attach(webpConfig, alloc, detach: webpConfig);

    return webpConfig;
  }

  @override
  int get lossless => _ffi.ref.lossless;
  @override
  set lossless(int value) => _ffi.ref.lossless = value;

  @override
  double get quality => _ffi.ref.quality;
  @override
  set quality(double value) => _ffi.ref.quality = value;

  @override
  int get method => _ffi.ref.method;
  @override
  set method(int value) => _ffi.ref.method = value;

  @override
  int get imageHint => _ffi.ref.image_hint;
  @override
  set imageHint(int value) => _ffi.ref.image_hint = value;

  @override
  int get targetSize => _ffi.ref.target_size;
  @override
  set targetSize(int value) => _ffi.ref.target_size = value;

  @override
  double get targetPSNR => _ffi.ref.target_PSNR;
  @override
  set targetPSNR(double value) => _ffi.ref.target_PSNR = value;

  @override
  int get segments => _ffi.ref.segments;
  @override
  set segments(int value) => _ffi.ref.segments = value;

  @override
  int get snsStrength => _ffi.ref.sns_strength;
  @override
  set snsStrength(int value) => _ffi.ref.sns_strength = value;

  @override
  int get filterStrength => _ffi.ref.filter_strength;
  @override
  set filterStrength(int value) => _ffi.ref.filter_strength = value;

  @override
  int get filterSharpness => _ffi.ref.filter_sharpness;
  @override
  set filterSharpness(int value) => _ffi.ref.filter_sharpness = value;

  @override
  int get filterType => _ffi.ref.filter_type;
  @override
  set filterType(int value) => _ffi.ref.filter_type = value;

  @override
  int get autofilter => _ffi.ref.autofilter;
  @override
  set autofilter(int value) => _ffi.ref.autofilter = value;

  @override
  int get alphaCompression => _ffi.ref.alpha_compression;
  @override
  set alphaCompression(int value) => _ffi.ref.alpha_compression = value;

  @override
  int get alphaFiltering => _ffi.ref.alpha_filtering;
  @override
  set alphaFiltering(int value) => _ffi.ref.alpha_filtering = value;

  @override
  int get alphaQuality => _ffi.ref.alpha_quality;
  @override
  set alphaQuality(int value) => _ffi.ref.alpha_quality = value;

  @override
  int get pass => _ffi.ref.pass;
  @override
  set pass(int value) => _ffi.ref.pass = value;

  @override
  int get showCompressed => _ffi.ref.show_compressed;
  @override
  set showCompressed(int value) => _ffi.ref.show_compressed = value;

  @override
  int get preprocessing => _ffi.ref.preprocessing;
  @override
  set preprocessing(int value) => _ffi.ref.preprocessing = value;

  @override
  int get partitions => _ffi.ref.partitions;
  @override
  set partitions(int value) => _ffi.ref.partitions = value;

  @override
  int get partitionLimit => _ffi.ref.partition_limit;
  @override
  set partitionLimit(int value) => _ffi.ref.partition_limit = value;

  @override
  int get emulateJpegSize => _ffi.ref.emulate_jpeg_size;
  @override
  set emulateJpegSize(int value) => _ffi.ref.emulate_jpeg_size = value;

  @override
  int get threadLevel => _ffi.ref.thread_level;
  @override
  set threadLevel(int value) => _ffi.ref.thread_level = value;

  @override
  int get lowMemory => _ffi.ref.low_memory;
  @override
  set lowMemory(int value) => _ffi.ref.low_memory = value;

  @override
  int get nearLossless => _ffi.ref.near_lossless;
  @override
  set nearLossless(int value) => _ffi.ref.near_lossless = value;

  @override
  int get exact => _ffi.ref.exact;
  @override
  set exact(int value) => _ffi.ref.exact = value;

  @override
  int get useDeltaPalette => _ffi.ref.use_delta_palette;
  @override
  set useDeltaPalette(int value) => _ffi.ref.use_delta_palette = value;

  @override
  int get useSharpYuv => _ffi.ref.use_sharp_yuv;
  @override
  set useSharpYuv(int value) => _ffi.ref.use_sharp_yuv = value;

  @override
  int get qmin => _ffi.ref.qmin;
  @override
  set qmin(int value) => _ffi.ref.qmin = value;

  @override
  int get qmax => _ffi.ref.qmax;
  @override
  set qmax(int value) => _ffi.ref.qmax = value;
}

extension on WebPConfig? {
  Pointer<bindings.WebPConfig> get ptr => this?._ffi ?? nullptr;
}
