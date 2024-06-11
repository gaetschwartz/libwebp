import 'dart:ffi';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:libwebp/src/finalizers.dart';
import 'package:libwebp/src/libwebp.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart' as bindings;
import 'package:libwebp/src/utils.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

typedef WebPEncoderFinalizable = ({
  Arena arena,
  Pointer<bindings.WebPAnimEncoder> encoder
});

enum ResizeMode {
  /// Resize the image to fit within the specified dimensions while maintaining
  /// the original aspect ratio. The image may be shorter or narrower than
  /// specified.
  fit,

  /// Resize the image to fit within the specified dimensions while maintaining
  /// the original aspect ratio. The image may be larger than specified.
  stretch,
}

class WebPAnimEncoder implements Finalizable {
  static final _logger = Logger('WebPAnimEncoder');
  static final webPAnimEncoderDeletePtr =
      rawBindings.lookup<NativeFunction<bindings.NativeWebPAnimEncoderDelete>>(
    'WebPAnimEncoderDelete',
  );

  final Pointer<bindings.WebPAnimEncoder> _encoder;
  final WebPConfig? config;
  final int width;
  final int height;
  final WebPAnimEncoderOptions options;
  final ResizeMode resizeMode;
  bool _disposed = false;

  factory WebPAnimEncoder({
    required int width,
    required int height,
    WebPConfig? config,
    WebPAnimEncoderOptions? options,
    ResizeMode resizeMode = ResizeMode.stretch,
  }) {
    final opts = options ?? WebPAnimEncoderOptions();

    final encoder = checkAlloc(libwebp.WebPAnimEncoderNewInternal(
      width,
      height,
      opts._ffi,
      bindings.WEBP_MUX_ABI_VERSION,
    ));

    final wrapper = WebPAnimEncoder._(
      encoder: encoder,
      config: config,
      width: width,
      height: height,
      options: opts,
      resizeMode: resizeMode,
    );
    encoderFinalizer.attach(
      wrapper,
      encoder,
      detach: wrapper,
    );
    return wrapper;
  }

  WebPAnimEncoder._({
    required Pointer<bindings.WebPAnimEncoder> encoder,
    required this.config,
    required this.width,
    required this.height,
    required this.options,
    required this.resizeMode,
  })  : _encoder = encoder,
        _timestamp = 0;

  int _timestamp;
  int _frame = 0;

  int get currentTimestamp => _timestamp;

  void log(String message) {
    if (options.verbose) _logger.finer(message);
  }

  void add(WebPImage image, WebPAnimationTiming timings) {
    if (_disposed) {
      throw StateError('WebPAnimEncoder has been disposed.');
    }

    final info = image.info;

    log('Adding image with ${info.frameCount} frames');

    final frameBase = _frame;
    using((a) {
      final pic = a<bindings.WebPPicture>();
      check(
        libwebp.WebPPictureInitInternal(
          pic,
          bindings.WEBP_ENCODER_ABI_VERSION,
        ),
        'Failed to init WebPPicture.',
      );
      pic.ref.use_argb = 1;
      pic.ref.width = info.canvasWidth;
      pic.ref.height = info.canvasHeight;

      check(
        libwebp.WebPPictureAlloc(pic),
        'Failed to allocate WebPPicture.',
      );

      final (int, int) wh = switch (resizeMode) {
        ResizeMode.fit => width > height
            ? (width, (height * info.canvasHeight) ~/ info.canvasWidth)
            : ((width * info.canvasWidth) ~/ info.canvasHeight, height),
        ResizeMode.stretch => (width, height),
      };

      for (final frame in image.frames) {
        final duration = timings.frames.elementAt(_frame - frameBase);

        if (duration == Duration.zero) {
          log('  Skipping frame $_frame');
          _frame++;
          continue;
        }

        log('  Adding frame $_frame at $_timestamp ms');

        check(
          libwebp.WebPPictureImportRGBA(
            pic,
            frame.data,
            info.canvasWidth * 4,
          ),
          'Failed to import RGBA data.',
        );

        // WebPPictureRescale:
        //   Rescale a picture to new dimension width x height. If either 'width' or 'height' (but not both) is 0 the corresponding dimension will be calculated preserving the aspect ratio. No gamma correction is applied. Returns false in case of error (invalid parameter or insufficient memory).

        check(
          libwebp.WebPPictureRescale(
            pic,
            wh.$1,
            wh.$2,
          ),
          'Failed to rescale WebPPicture.',
        );

        check(
          libwebp.WebPAnimEncoderAdd(
            _encoder,
            pic,
            _timestamp,
            config.ptr,
          ),
          'Failed to add frame $_frame to encoder.',
          pic: pic,
          encoder: _encoder,
        );

        _timestamp += duration.inMilliseconds;
        _frame++;

        libwebp.WebPPictureFree(pic);
      }
    });
  }

  Duration get duration => Duration(milliseconds: _timestamp);

  int get frameCount => _frame;

  WebPData assemble() {
    if (_disposed) {
      throw StateError('WebPAnimEncoder has been disposed.');
    }
// add a blank frame to make sure the last frame is included
    log('Adding blank frame at $_timestamp ms');
    check(
      libwebp.WebPAnimEncoderAdd(
        _encoder,
        nullptr,
        _timestamp,
        config.ptr,
      ),
      'Failed to add blank frame to encoder.',
      encoder: _encoder,
    );

    final data = WebPData(freeInnerBuffer: false);

    check(
      libwebp.WebPAnimEncoderAssemble(_encoder, data.ptr),
      'Failed to assemble WebP.',
      encoder: _encoder,
    );

    return data;
  }

  void free() {
    if (_disposed) {
      throw StateError('WebPAnimEncoder has been disposed.');
    }
    libwebp.WebPAnimEncoderDelete(_encoder);
    encoderFinalizer.detach(this);
    _disposed = true;
  }
}

final class WebPData implements Finalizable {
  bool _disposed = false;
  final bool freeInnerBuffer;
  final bool freeData;

  final Pointer<bindings.WebPData> ptr;

  /// Pointer to the data.
  @internal
  Pointer<Uint8> get bytes {
    if (_disposed) {
      throw StateError('WebPData has been disposed.');
    }
    return ptr.ref.bytes;
  }

  @internal
  set bytes(Pointer<Uint8> value) {
    if (_disposed) {
      throw StateError('WebPData has been disposed.');
    }
    ptr.ref.bytes = value;
  }

  /// Size of the data.
  @internal
  int get size {
    if (_disposed) {
      throw StateError('WebPData has been disposed.');
    }
    return ptr.ref.size;
  }

  @internal
  set size(int value) {
    if (_disposed) {
      throw StateError('WebPData has been disposed.');
    }
    ptr.ref.size = value;
  }

  Uint8List get asTypedList {
    if (_disposed) {
      throw StateError('WebPData has been disposed.');
    }
    return bytes.asTypedList(size);
  }

  factory WebPData({
    bool freeInnerBuffer = false,
  }) {
    final ptr = calloc<bindings.WebPData>();

    final wrapper = WebPData._(ptr, freeInnerBuffer: freeInnerBuffer);

    callocFinalizer.attach(wrapper, ptr.cast(), detach: wrapper);
    if (freeInnerBuffer) {
      webpFreeFinalizer.attach(wrapper, ptr.ref.bytes.cast(), detach: wrapper);
    }

    return wrapper;
  }

  WebPData._(this.ptr, {required this.freeInnerBuffer}) : freeData = true;
  WebPData.view(this.ptr)
      : freeData = false,
        freeInnerBuffer = false;

  void free() {
    if (_disposed) {
      throw StateError('WebPData has been disposed.');
    }
    if (freeData) {
      calloc.free(ptr);
      callocFinalizer.detach(this);
    }

    if (freeInnerBuffer) {
      libwebp.WebPFree(ptr.ref.bytes.cast());
      webpFreeFinalizer.detach(this);
    }
    _disposed = true;
  }
}

final class WebPAnimEncoderOptions implements Finalizable {
  final Pointer<bindings.WebPAnimEncoderOptions> _ffi;

  /// Animation parameters.

  /// Animation parameters.
  bindings.WebPMuxAnimParams get animParams => _ffi.ref.anim_params;

  /// Animation parameters.
  set animParams(bindings.WebPMuxAnimParams value) {
    _ffi.ref.anim_params = value;
  }

  /// If true, minimize the output size (slow). Implicitly
  /// disables key-frame insertion.

  /// If true, minimize the output size (slow). Implicitly
  /// disables key-frame insertion.
  bool get minimizeSize => _ffi.ref.minimize_size == 1;

  /// If true, minimize the output size (slow). Implicitly
  /// disables key-frame insertion.
  set minimizeSize(bool value) {
    _ffi.ref.minimize_size = value ? 1 : 0;
  }

  /// Minimum and maximum distance between consecutive key
  /// frames in the output. The library may insert some key
  /// frames as needed to satisfy this criteria.
  /// Note that these conditions should hold: kmax > kmin
  /// and kmin >= kmax / 2 + 1. Also, if kmax <= 0, then
  /// key-frame insertion is disabled; and if kmax == 1,
  /// then all frames will be key-frames (kmin value does
  /// not matter for these special cases).
  int get kmin => _ffi.ref.kmin;

  /// Minimum and maximum distance between consecutive key
  /// frames in the output. The library may insert some key
  /// frames as needed to satisfy this criteria.
  /// Note that these conditions should hold: kmax > kmin
  /// and kmin >= kmax / 2 + 1. Also, if kmax <= 0, then
  /// key-frame insertion is disabled; and if kmax == 1,
  /// then all frames will be key-frames (kmin value does
  /// not matter for these special cases).
  set kmin(int value) {
    _ffi.ref.kmin = value;
  }

  int get kmax => _ffi.ref.kmax;
  set kmax(int value) {
    _ffi.ref.kmax = value;
  }

  /// If true, use mixed compression mode; may choose
  /// either lossy and lossless for each frame.
  bool get allowMixed => _ffi.ref.allow_mixed == 1;

  /// If true, use mixed compression mode; may choose
  /// either lossy and lossless for each frame.
  set allowMixed(bool value) {
    _ffi.ref.allow_mixed = value ? 1 : 0;
  }

  /// If true, print info and warning messages to stderr.

  bool get verbose => _ffi.ref.verbose == 1;

  set verbose(bool value) {
    _ffi.ref.verbose = value ? 1 : 0;
  }

  factory WebPAnimEncoderOptions({
    bool? minimizeSize,
    int? kmin,
    int? kmax,
    bool? allowMixed,
    bool? verbose,
  }) {
    final opts = calloc<bindings.WebPAnimEncoderOptions>();

    check(
      libwebp.WebPAnimEncoderOptionsInitInternal(
        opts,
        bindings.WEBP_MUX_ABI_VERSION,
      ),
      'Failed to initialize WebPAnimEncoderOptions.',
    );

    if (minimizeSize case final minimizeSize?) {
      opts.ref.minimize_size = minimizeSize ? 1 : 0;
    }
    if (kmin case final kmin?) {
      opts.ref.kmin = kmin;
    }
    if (kmax case final kmax?) {
      opts.ref.kmax = kmax;
    }
    if (allowMixed case final allowMixed?) {
      opts.ref.allow_mixed = allowMixed ? 1 : 0;
    }
    if (verbose case final verbose?) {
      opts.ref.verbose = verbose ? 1 : 0;
    }

    final wrapper = WebPAnimEncoderOptions._(opts);

    callocFinalizer.attach(wrapper, opts.cast(), detach: wrapper);

    return wrapper;
  }

  const WebPAnimEncoderOptions._(this._ffi);
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

class WebPConfig implements _WebpConfigBase, Finalizable {
  factory WebPConfig({
    WebPPreset preset = WebPPreset.default_,
    double quality = 75.0,
  }) {
    final cfg = calloc<bindings.WebPConfig>();
    check(
      libwebp.WebPConfigInitInternal(
        cfg,
        preset.value,
        quality,
        bindings.WEBP_ENCODER_ABI_VERSION,
      ),
      'Failed to init WebPConfig.',
    );

    final webpConfig = WebPConfig._(cfg);

    callocFinalizer.attach(webpConfig, cfg.cast(), detach: webpConfig);

    return webpConfig;
  }

  const WebPConfig._(this._ffi);

  final Pointer<bindings.WebPConfig> _ffi;

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

typedef WebPAnimationTimingTransformer = Duration Function(
  int frame,
  Duration duration,
);

sealed class WebPAnimationTiming {
  const WebPAnimationTiming();

  Iterable<Duration> get frames;

  double get fps;

  @pragma('vm:prefer-inline')
  WebPAnimationTiming map(WebPAnimationTimingTransformer mapper) {
    return MappedWebPAnimationTiming(this, mapper);
  }

  Duration at(int index) => frames.elementAt(index);

  Duration get totalDuration => frames.sum;

  WebPAnimationTiming reduceFps(int divisor) {
    return MappedWebPAnimationTiming(
      this,
      (i, dur) => i % divisor == 0 ? (dur * divisor) : Duration.zero,
    );
  }
}

class ListWebPAnimationTiming extends WebPAnimationTiming {
  final List<Duration> value;

  @override
  Iterable<Duration> get frames => value;

  @override
  double get fps =>
      1000 * value.length / value.map((e) => e.inMilliseconds).sum;

  const ListWebPAnimationTiming(this.value);
}

class ConstantWebPAnimationTiming extends WebPAnimationTiming {
  final Duration duration;
  final int length;

  @override
  Iterable<Duration> get frames => Iterable.generate(length, (_) => duration);

  @override
  double get fps => 1000 / duration.inMilliseconds;

  const ConstantWebPAnimationTiming(this.duration, this.length);
}

class MappedWebPAnimationTiming extends WebPAnimationTiming {
  final WebPAnimationTiming source;
  final WebPAnimationTimingTransformer transformer;

  @override
  Iterable<Duration> get frames => Iterable.generate(
        source.frames.length,
        (i) => transformer(i, source.frames.elementAt(i)),
      );

  @override
  double get fps {
    final (:len, :sum) = frames.nonZero.fold<({int len, Duration sum})>(
      (len: 0, sum: Duration.zero),
      (acc, e) => (len: acc.len + 1, sum: acc.sum + e),
    );

    return 1000 * len / sum.inMilliseconds;
  }

  const MappedWebPAnimationTiming(this.source, this.transformer);
}

extension IterDuration on Iterable<Duration> {
  Duration get sum => reduce((a, b) => a + b);

  Iterable<Duration> get nonZero => where((e) => e != Duration.zero);
}
