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
    final os = Platform.operatingSystem;
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
    case OperatingSystem.linux:
      return DynamicLibrary.open('lib$_libName.so');
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
      return DynamicLibrary.open('libwebp.dll');
    case OperatingSystem.fuchsia:
      throw UnsupportedError('Fuchsia is not supported.');
    case OperatingSystem.unknown:
      throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
  }
}

final webPMemoryWritePtr = _openLib()
    .lookup<NativeFunction<bindings.NativeWebPMemoryWrite>>('WebPMemoryWrite');

/// The bindings to the native WebP library.
final libwebp = bindings.LibwebpFlutterLibsBindings(_openLib());

class LibWebPVersions {
  final String? decoder;
  final String? encoder;
  final String? mux;
  final String? demux;

  LibWebPVersions._({
    required this.decoder,
    required this.encoder,
    required this.mux,
    required this.demux,
  });

  factory LibWebPVersions.fromNative() {
    return LibWebPVersions._(
      decoder: _try(_getWebpDecoderVersion),
      encoder: _try(_getWebpEncoderVersion),
      mux: _try(_getWebpMuxVersion),
      demux: _try(_getWebpDemuxVersion),
    );
  }

  @override
  String toString() {
    return 'LibWebPVersions(decoder: $decoder, encoder: $encoder, mux: $mux, demux: $demux)';
  }

  static T? _try<T>(T Function() f) {
    try {
      return f();
      // ignore: avoid_catching_errors
    } on ArgumentError catch (e) {
      print('Failed to get version: $e');
      return null;
    }
  }

  static String _getWebpDecoderVersion() {
    // Return the decoder's version number, packed in hexadecimal using 8bits for each of major/minor/revision. E.g: v2.5.7 is 0x020507.
    final version = libwebp.WebPGetDecoderVersion();
    final (major, minor, revision) =
        (version >> 16, (version >> 8) & 0xff, version & 0xff);
    return '$major.$minor.$revision';
  }

  static String _getWebpEncoderVersion() {
    // Return the encoder's version number, packed in hexadecimal using 8bits for each of major/minor/revision. E.g: v2.5.7 is 0x020507.
    final version = libwebp.WebPGetEncoderVersion();
    final (major, minor, revision) =
        (version >> 16, (version >> 8) & 0xff, version & 0xff);
    return '$major.$minor.$revision';
  }

  static String _getWebpMuxVersion() {
    // Return the mux's version number, packed in hexadecimal using 8bits for each of major/minor/revision. E.g: v2.5.7 is 0x020507.
    final version = libwebp.WebPGetMuxVersion();
    final (major, minor, revision) =
        (version >> 16, (version >> 8) & 0xff, version & 0xff);
    return '$major.$minor.$revision';
  }

  static String _getWebpDemuxVersion() {
    // Return the demux's version number, packed in hexadecimal using 8bits for each of major/minor/revision. E.g: v2.5.7 is 0x020507.
    final version = libwebp.WebPGetDemuxVersion();
    final (major, minor, revision) =
        (version >> 16, (version >> 8) & 0xff, version & 0xff);
    return '$major.$minor.$revision';
  }
}

({int width, int height}) getWebpDimensions(FfiByteData data) {
  return using((a) {
    final curr = (width: a<Int>(), height: a<Int>());
    final res =
        libwebp.WebPGetInfo(data.ptr, data.size, curr.width, curr.height);
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
    using((Arena alloc) {
      final data = alloc.byteData(input.length);
      data.asList.setAll(0, input);
      final curr = getWebpDimensions(data);

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
  final encoder = libwebp.WebPAnimEncoderNewInternal(
    targetDimensions.width,
    targetDimensions.height,
    nullptr,
    bindings.WEBP_MUX_ABI_VERSION,
  );

  final cfg = alloc<bindings.WebPConfig>();
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

  final animDecoder = _animDecoder(alloc, data);
  final info = alloc<bindings.WebPAnimInfo>();
  check(
      libwebp.WebPAnimDecoderGetInfo(animDecoder, info), 'Failed to get info.');
  log.fine('''
Rescaling WebP:
    canvas_width: ${info.ref.canvas_width}
    canvas_height: ${info.ref.canvas_height}
    loop_count: ${info.ref.loop_count}
    bgcolor: ${info.ref.bgcolor}
    frame_count: ${info.ref.frame_count}
  ''');

  final timestamp = alloc<Int>();
  final buf = alloc<Pointer<Uint8>>();
  for (int i = 0; i < info.ref.frame_count; i++) {
    // print('frame $i');
    check(
      libwebp.WebPAnimDecoderGetNext(animDecoder, buf, timestamp),
      'Failed to get next frame.',
    );

    final frame = alloc<bindings.WebPPicture>();
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

    final added = libwebp.WebPAnimEncoderAdd(
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
  final added =
      libwebp.WebPAnimEncoderAdd(encoder, nullptr, timestamp.value, nullptr);
  if (added == 0) {
    throw LibWebPException('Failed to add frame null frame to encoder.');
  }

  final out = alloc<bindings.WebPData>();
  final size = libwebp.WebPAnimEncoderAssemble(encoder, out);
  if (size == 0) {
    throw LibWebPException('Failed to assemble WebP.');
  }

  final uint8list = Uint8List.fromList(out.ref.bytes.asTypedList(out.ref.size));

  libwebp.WebPAnimDecoderDelete(animDecoder);
  libwebp.WebPAnimEncoderDelete(encoder);

  return uint8list;
}

Pointer<bindings.WebPAnimDecoder> _animDecoder(Allocator a, FfiByteData data) {
  final webpData = a<bindings.WebPData>();
  webpData.ref.bytes = data.ptr;
  webpData.ref.size = data.size;

  final opt = a<bindings.WebPAnimDecoderOptions>();
  libwebp.WebPAnimDecoderOptionsInitInternal(
      opt, bindings.WEBP_DEMUX_ABI_VERSION);
  opt.ref.color_mode = bindings.WEBP_CSP_MODE.MODE_RGBA;

  final decoder = checkAlloc(libwebp.WebPAnimDecoderNewInternal(
    webpData,
    opt,
    bindings.WEBP_DEMUX_ABI_VERSION,
  ));

  return decoder;
}

// ({int width, int height, int top, int left}) _contain({
//   required ({int width, int height}) src,
//   required ({int width, int height}) target,
// }) {
//   final srcRatio = src.width / src.height;
//   final targetRatio = target.width / target.height;

//   final width =
//       srcRatio > targetRatio ? target.width : (target.height * srcRatio);
//   final height =
//       srcRatio > targetRatio ? (target.width / srcRatio) : target.height;

//   final top = (target.height - height) ~/ 2;
//   final left = (target.width - width) ~/ 2;

//   return (width: width.toInt(), height: height.toInt(), top: top, left: left);
// }

// ({int width, int height, int top, int left}) _fill({
//   required ({int width, int height}) src,
//   required ({int width, int height}) target,
// }) {
//   return (width: src.width, height: src.height, top: 0, left: 0);
// }
