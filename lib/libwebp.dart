import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp_generated_bindings.dart';
import 'package:libwebp/src/utils.dart';

bool get isTest => Platform.environment['FLUTTER_TEST'] == 'true';

const String _libName = 'libwebp_flutter_libs';

/// The dynamic library in which the symbols for [LibwebpFlutterLibsBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isMacOS) {
    if (isTest) {
      return DynamicLibrary.open(
          'build/macos/Build/Products/Release/libwebp/libwebp.framework/libwebp');
    }

    const libName = 'libwebp';

    return DynamicLibrary.open('$libName.framework/$libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('libwebp.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final libwebp = LibwebpFlutterLibsBindings(_dylib);

({int width, int height}) getWebpDimensions(Uint8Data data) {
  return using((a) {
    final curr = (width: a<Int>(), height: a<Int>());
    final res =
        libwebp.WebPGetInfo(data.ptr, data.length, curr.width, curr.height);
    if (res == 0) {
      throw LibWebpException('Failed to get WebP info.');
    }
    return (width: curr.width.value, height: curr.height.value);
  });
}

Uint8List resizeWebp(
  Uint8List input,
  ({int width, int height}) targetDimensions,
) =>
    using((Arena alloc) {
      final data = alloc.uint8Array(input.length);
      data.asList.setAll(0, input);
      final curr = getWebpDimensions(data);

      Uint8List outData = _resizeWebp(alloc, curr, targetDimensions, data);

      return outData;
    });

Uint8List _resizeWebp(
  Arena alloc,
  ({int height, int width}) curr,
  ({int height, int width}) targetDimensions,
  Uint8Data data,
) {
  final encoder = libwebp.WebPAnimEncoderNewInternal(
    targetDimensions.width,
    targetDimensions.height,
    nullptr,
    WEBP_DEMUX_ABI_VERSION,
  );

  final cfg = alloc<WebPConfig>();
  _check(
    libwebp.WebPConfigInitInternal(
      cfg,
      WebPPreset.WEBP_PRESET_DEFAULT,
      75,
      WEBP_ENCODER_ABI_VERSION,
    ),
    'Failed to init WebPConfig.',
  );
  cfg.ref.thread_level = 1;

  final animDecoder = _animDecoder(alloc, data);
  final info = alloc<WebPAnimInfo>();
  _check(
      libwebp.WebPAnimDecoderGetInfo(animDecoder, info), 'Failed to get info.');
  print('''
  info:
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
    _check(
      libwebp.WebPAnimDecoderGetNext(animDecoder, buf, timestamp),
      'Failed to get next frame.',
    );

    final frame = alloc<WebPPicture>();
    _check(
      libwebp.WebPPictureInitInternal(frame, WEBP_ENCODER_ABI_VERSION),
      'Failed to init WebPPicture.',
    );
    frame.ref.use_argb = 1; // use ARGB
    frame.ref.width = curr.width;
    frame.ref.height = curr.height;
    _check(
      libwebp.WebPPictureAlloc(frame),
      'Failed to allocate WebPPicture.',
    );
    _check(
      libwebp.WebPPictureImportRGBA(frame, buf.value, curr.width * 4),
      'Failed to import frame $i to WebPPicture.',
    );
    _check(
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
      throw LibWebpException(
          'Failed to add frame $i to encoder. (${VP8StatusCode.fromValue(frame.ref.error_code)}, ${str.toDartString()})');
    }

    libwebp.WebPPictureFree(frame);
  }
  final added =
      libwebp.WebPAnimEncoderAdd(encoder, nullptr, timestamp.value, nullptr);
  if (added == 0) {
    throw LibWebpException('Failed to add frame null frame to encoder.');
  }

  final out = alloc<WebPData>();
  final size = libwebp.WebPAnimEncoderAssemble(encoder, out);
  if (size == 0) {
    throw LibWebpException('Failed to assemble WebP.');
  }

  final uint8list = Uint8List.fromList(out.ref.bytes.asTypedList(out.ref.size));

  libwebp.WebPAnimDecoderDelete(animDecoder);
  libwebp.WebPAnimEncoderDelete(encoder);

  return uint8list;
}

int _hasMoreFrames(Pointer<WebPAnimDecoder> animDecoder) =>
    libwebp.WebPAnimDecoderHasMoreFrames(animDecoder);

Pointer<WebPAnimDecoder> _animDecoder(Allocator a, Uint8Data data) {
  final webpData = a<WebPData>();
  webpData.ref.bytes = data.ptr;
  webpData.ref.size = data.length;

  final opt = a<WebPAnimDecoderOptions>();
  libwebp.WebPAnimDecoderOptionsInitInternal(opt, WEBP_DEMUX_ABI_VERSION);
  opt.ref.color_mode = WEBP_CSP_MODE.MODE_RGBA;

  final decoder = libwebp.WebPAnimDecoderNewInternal(
    webpData,
    opt,
    WEBP_DEMUX_ABI_VERSION,
  );
  if (decoder == nullptr) {
    throw LibWebpException('Failed to create WebPAnimDecoder.');
  }

  return decoder;
}

class LibWebpException implements Exception {
  final String message;

  LibWebpException(this.message);

  @override
  String toString() => 'LibWebpException: $message';
}

enum VP8StatusCode {
  ok(0),
  outOfMemory(1),
  invalidParam(2),
  bitstreamError(3),
  unsupportedFeature(4),
  suspended(5),
  userAbort(6),
  notEnoughData(7),
  ;

  final int value;
  const VP8StatusCode(this.value);

  factory VP8StatusCode.fromValue(int value) {
    return VP8StatusCode.values.firstWhere((e) => e.value == value);
  }
}

void _check(int res, [String? message]) {
  if (res == 0) {
    throw LibWebpException(message ?? 'Failed with error code $res.');
  }
}
