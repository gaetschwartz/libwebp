import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp_generated_bindings.dart';
import 'package:libwebp/src/utils.dart';

const String _libName = 'libwebp_flutter_libs';

/// The dynamic library in which the symbols for [LibwebpFlutterLibsBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
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
        Uint8List input, ({int? width, int? height}) targetDimensions) =>
    using((Arena alloc) {
      final data = alloc.uint8Array(input.length);
      data.asList.setAll(0, input);
      final curr = getWebpDimensions(data);

      final decoderConfig = alloc<WebPDecoderConfig>();
      libwebp.WebPInitDecoderConfigInternal(
        decoderConfig,
        WEBP_DECODER_ABI_VERSION,
      );

      decoderConfig.ref.output.colorspace = WEBP_CSP_MODE.MODE_RGBA;
      decoderConfig.ref.output.width = curr.width;
      decoderConfig.ref.output.height = curr.height;

      decoderConfig.ref.options.use_scaling = 1;
      decoderConfig.ref.options.scaled_width = targetDimensions.width ?? 0;
      decoderConfig.ref.options.scaled_height = targetDimensions.height ?? 0;

      final res2 = libwebp.WebPDecode(data.ptr, data.length, decoderConfig);
      if (res2 != VP8StatusCode.VP8_STATUS_OK) {
        throw LibWebpException('Failed to decode WebP, got status code $res2.');
      }

      final outPtr = alloc<Pointer<Uint8>>();

      final outputSize = libwebp.WebPEncodeRGBA(
        decoderConfig.ref.output.u.RGBA.rgba,
        decoderConfig.ref.output.width,
        decoderConfig.ref.output.height,
        decoderConfig.ref.output.u.RGBA.stride,
        100,
        outPtr,
      );

      if (outputSize == 0) {
        throw LibWebpException('Failed to encode WebP.');
      }

      final outList = outPtr.value.asTypedList(outputSize);
      final outData = Uint8List.fromList(outList);

      libwebp.WebPFree(outPtr.value as Pointer<Void>);

      return outData;
    });

class LibWebpException implements Exception {
  final String message;

  LibWebpException(this.message);

  @override
  String toString() => 'LibWebpException: $message';
}
