import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart' as bindings;
import 'package:libwebp/src/utils.dart';
import 'package:logging/logging.dart';

bool get isTest => Platform.environment['FLUTTER_TEST'] == 'true';

const _libName = 'libwebp_flutter_libs';

enum OperatingSystem {
  android,
  fuchsia,
  ios,
  linux,
  macos,
  windows,
  unknown,
  ;

  static OperatingSystem get current {
    final String os = Platform.operatingSystem;
    return switch (os) {
      'android' => OperatingSystem.android,
      'fuchsia' => OperatingSystem.fuchsia,
      'ios' => OperatingSystem.ios,
      'linux' => OperatingSystem.linux,
      'macos' => OperatingSystem.macos,
      'windows' => OperatingSystem.windows,
      _ => OperatingSystem.unknown,
    };
  }
}

DynamicLibrary _openLib() {
  switch (OperatingSystem.current) {
    case OperatingSystem.android:
      return DynamicLibrary.open('$_libName.so');
    case OperatingSystem.linux:
      return DynamicLibrary.open('$_libName.so');
    case OperatingSystem.ios:
      return DynamicLibrary.open('$_libName.framework/$_libName');
    case OperatingSystem.macos:
      const libName = 'libwebp';

      if (isTest) {
        return DynamicLibrary.open(
          'build/macos/Build/Products/Release/$libName/$libName.framework/libwebp',
        );
      }

      return DynamicLibrary.open('$libName.framework/$libName');
    case OperatingSystem.windows:
      DynamicLibrary.open('libsharpyuv.dll');
      DynamicLibrary.open('libwebpdemux.dll');
      DynamicLibrary.open('libwebpmux.dll');
      DynamicLibrary.open('libwebpdecoder.dll');
      DynamicLibrary.open('libwebp.dll');
      return DynamicLibrary.process();
    case OperatingSystem.fuchsia:
      throw UnsupportedError('Fuchsia is not supported.');
    case OperatingSystem.unknown:
      throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
  }
}

final rawBindings = _openLib();

final webPMemoryWritePtr = rawBindings.lookup<NativeFunction<bindings.NativeWebPMemoryWrite>>('WebPMemoryWrite');

/// The bindings to the native WebP library.
final libwebp = bindings.LibwebpFlutterLibsBindings(rawBindings);

class LibWebPVersions {
  final LibWebPFrameworkInfo decoder;
  final LibWebPFrameworkInfo encoder;
  final LibWebPFrameworkInfo mux;
  final LibWebPFrameworkInfo demux;

  LibWebPVersions._({
    required this.decoder,
    required this.encoder,
    required this.mux,
    required this.demux,
  });

  factory LibWebPVersions.fromNative() {
    return LibWebPVersions._(
      decoder: _getVersion(libwebp.WebPGetDecoderVersion, 'decoder'),
      encoder: _getVersion(libwebp.WebPGetEncoderVersion, 'encoder'),
      mux: _getVersion(libwebp.WebPGetMuxVersion, 'mux'),
      demux: _getVersion(libwebp.WebPGetDemuxVersion, 'demux'),
    );
  }

  @override
  String toString() {
    return 'LibWebPVersions(decoder: $decoder, encoder: $encoder, mux: $mux, demux: $demux)';
  }

  static LibWebPFrameworkInfo _getVersion(int Function() f, String frameworkName) {
    try {
      return LibWebPFrameworkVersion(Version.fromInt(f()));
      // ignore: avoid_catching_errors
    } on ArgumentError catch (e) {
      return LibWebPFrameworkMissing(frameworkName, e);
    }
  }
}

class Version {
  final int major;
  final int minor;
  final int patch;

  const Version(this.major, this.minor, this.patch);

  factory Version.fromInt(int version) {
    return Version(
      version >> 16,
      (version >> 8) & 0xff,
      version & 0xff,
    );
  }

  @override
  String toString() => '$major.$minor.$patch';
}

sealed class LibWebPFrameworkInfo {
  const LibWebPFrameworkInfo();
}

class LibWebPFrameworkVersion extends LibWebPFrameworkInfo {
  final Version version;

  const LibWebPFrameworkVersion(this.version);

  @override
  String toString() => version.toString();
}

class LibWebPFrameworkMissing extends LibWebPFrameworkInfo implements Exception {
  final String frameworkName;
  final ArgumentError error;

  const LibWebPFrameworkMissing(this.frameworkName, this.error);

  @override
  String toString() {
    return 'LibWebPFrameworkMissing: $frameworkName ($error)';
  }
}

({int width, int height}) getWebpDimensions(FfiByteData data) {
  return using((a) {
    final ({Pointer<Int> height, Pointer<Int> width}) curr = (width: a<Int>(), height: a<Int>());
    final int res = libwebp.WebPGetInfo(data.ptr, data.size, curr.width, curr.height);
    if (res == 0) {
      throw LibWebPException('Failed to get WebP info.');
    }
    return (width: curr.width.value, height: curr.height.value);
  });
}

enum BoxFit {
  fill,
  contain,
}

Uint8List resizeWebp(
  Uint8List input,
  ({int width, int height}) targetDimensions, {
  BoxFit fit = BoxFit.fill,
}) =>
    using((alloc) {
      final data = FfiByteData.fromTypedList(input);
      final ({int height, int width}) curr = getWebpDimensions(data);

      final Uint8List outData = _resizeWebp(
        alloc,
        curr,
        targetDimensions,
        data,
        fit: fit,
      );

      return outData;
    });

Uint8List _resizeWebp(
  Arena alloc,
  ({int height, int width}) curr,
  ({int height, int width}) targetDimensions,
  FfiByteData data, {
  BoxFit fit = BoxFit.fill,
}) {
  final log = Logger('resizeWebp');
  final Pointer<bindings.WebPAnimEncoder> encoder = libwebp.WebPAnimEncoderNewInternal(
    targetDimensions.width,
    targetDimensions.height,
    nullptr,
    bindings.WEBP_MUX_ABI_VERSION,
  );

  final Pointer<bindings.WebPConfig> cfg = alloc<bindings.WebPConfig>();
  check(
    libwebp.WebPConfigInitInternal(
      cfg,
      bindings.WebPPreset.WEBP_PRESET_DEFAULT,
      75,
      bindings.WEBP_ENCODER_ABI_VERSION,
    ),
    'Failed to init WebPConfig.',
  );
  cfg.ref.thread_level = 1;

  final Pointer<bindings.WebPAnimDecoder> animDecoder = _animDecoder(alloc, data);
  final Pointer<bindings.WebPAnimInfo> info = alloc<bindings.WebPAnimInfo>();
  check(libwebp.WebPAnimDecoderGetInfo(animDecoder, info), 'Failed to get info.');
  log.fine('''
Rescaling WebP:
    canvas_width: ${info.ref.canvas_width}
    canvas_height: ${info.ref.canvas_height}
    loop_count: ${info.ref.loop_count}
    bgcolor: ${info.ref.bgcolor}
    frame_count: ${info.ref.frame_count}
  ''');

  final Pointer<Int> timestamp = alloc<Int>();
  final Pointer<Pointer<Uint8>> buf = alloc<Pointer<Uint8>>();
  for (var i = 0; i < info.ref.frame_count; i++) {
    // print('frame $i');
    check(
      libwebp.WebPAnimDecoderGetNext(animDecoder, buf, timestamp),
      'Failed to get next frame.',
    );

    final Pointer<bindings.WebPPicture> frame = alloc<bindings.WebPPicture>();
    check(
      libwebp.WebPPictureInitInternal(frame, bindings.WEBP_ENCODER_ABI_VERSION),
      'Failed to init WebPPicture.',
    );
    frame.ref.use_argb = 1; // use ARGB
    frame.ref.width = curr.width;
    frame.ref.height = curr.height;
    check(
      libwebp.WebPPictureAlloc(frame),
      'Failed to allocate WebPPicture.',
    );
    check(
      libwebp.WebPPictureImportRGBA(frame, buf.value, curr.width * 4),
      'Failed to import frame $i to WebPPicture.',
    );

    check(
      libwebp.WebPPictureRescale(
        frame,
        targetDimensions.width,
        targetDimensions.height,
      ),
      'Failed to rescale frame $i.',
    );

    final int added = libwebp.WebPAnimEncoderAdd(
      encoder,
      frame,
      timestamp.value,
      cfg,
    );
    if (added == 0) {
      final str = libwebp.WebPAnimEncoderGetError(encoder) as Pointer<Utf8>;
      throw LibWebPException(
          'Failed to add frame $i to encoder. (${Vp8StatusCode.fromInt(frame.ref.error_code)}, ${str.toDartString()})');
    }

    libwebp.WebPPictureFree(frame);
  }
  final int added = libwebp.WebPAnimEncoderAdd(encoder, nullptr, timestamp.value, nullptr);
  if (added == 0) {
    throw LibWebPException('Failed to add frame null frame to encoder.');
  }

  final Pointer<bindings.WebPData> out = alloc<bindings.WebPData>();
  final int size = libwebp.WebPAnimEncoderAssemble(encoder, out);
  if (size == 0) {
    throw LibWebPException('Failed to assemble WebP.');
  }

  final uint8list = Uint8List.fromList(out.ref.bytes.asTypedList(out.ref.size));

  libwebp.WebPAnimDecoderDelete(animDecoder);
  libwebp.WebPAnimEncoderDelete(encoder);

  return uint8list;
}

Pointer<bindings.WebPAnimDecoder> _animDecoder(Allocator a, FfiByteData data) {
  final Pointer<bindings.WebPData> webpData = a<bindings.WebPData>();
  webpData.ref.bytes = data.ptr;
  webpData.ref.size = data.size;

  final Pointer<bindings.WebPAnimDecoderOptions> opt = a<bindings.WebPAnimDecoderOptions>();
  libwebp.WebPAnimDecoderOptionsInitInternal(opt, bindings.WEBP_DEMUX_ABI_VERSION);
  opt.ref.color_mode = bindings.WEBP_CSP_MODE.MODE_RGBA;

  final Pointer<bindings.WebPAnimDecoder> decoder = checkAlloc(libwebp.WebPAnimDecoderNewInternal(
    webpData,
    opt,
    bindings.WEBP_DEMUX_ABI_VERSION,
  ));

  return decoder;
}
