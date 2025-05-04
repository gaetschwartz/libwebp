import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:libwebp_platform_ffi_darwin/bindings/coregraphics.dart' as cg;
import 'package:libwebp_platform_ffi_darwin/bindings/coreimage.dart' as ci;
import 'package:libwebp_platform_ffi_darwin/bindings/libwebp.dart';
import 'package:objective_c/objective_c.dart';

typedef Dimensions = ({int width, int height});

final _dylib = DynamicLibrary.process();
final _webpBindings = WebPBindings(_dylib);
final _coregraphicsBindings = cg.CoreGraphicsBindings(_dylib);
final _coreimageBindings = ci.CoreImageBindings(_dylib);

class ResizeWebp {
  WebPDecodedRGBAFrame decodeFrame(Pointer<Uint8> imagedata, {required int size}) {
    return using((a) {
      final width = a<Int>();
      final height = a<Int>();

      final out = _webpBindings.WebPDecodeRGBA(imagedata, size, width, height);
      if (out == nullptr) {
        throw Exception('Failed to decode WebP image');
      }

      return WebPDecodedRGBAFrame(out, length: size, width: width.value, height: height.value);
    });
  }

  WebPEncodedRGBAFrame encodeFrame(Pointer<Uint8> data, Dimensions dimensions, {double quality = 100, int? size}) {
    return using((a) {
      final width = dimensions.width;
      final height = dimensions.height;
      final bufferPtr = a<Pointer<Uint8>>();

      final size = _webpBindings.WebPEncodeRGBA(data, width, height, 4 * width, quality, bufferPtr);
      if (size == 0) {
        throw Exception('Failed to encode WebP image');
      }

      return WebPEncodedRGBAFrame(bufferPtr.value, length: size, width: width, height: height);
    });
  }

  // using ios' CoreImage's CIImage to resize the image with GPU acceleration
  // imagedata is rgba8888
  cg.CFDataRef _resizeFrame(
    Pointer<Uint8> imagedata, {
    required int size,
    required Dimensions dimensions,
    required Dimensions targetDimensions,
  }) {
    return using((a) {
      // extern CGImageRef CGImageCreate(size_t width, size_t height, size_t bitsPerComponent, size_t bitsPerPixel, size_t bytesPerRow, CGColorSpaceRef space, CGBitmapInfo bitmapInfo, CGDataProviderRef provider, const CGFloat * decode, bool shouldInterpolate, CGColorRenderingIntent intent);>
      final width = dimensions.width;
      final height = dimensions.height;
      final bitsPerComponent = 8;
      final bitsPerPixel = 4 * width;
      final bytesPerRow = 4 * width;
      final colorSpace = _coregraphicsBindings.CGColorSpaceCreateDeviceRGB();
      final bitmapInfo = cg.CGBitmapInfo.kCGBitmapByteOrder32Big;
      final provider = _coregraphicsBindings.CGDataProviderCreateWithData(nullptr, imagedata.cast(), size, nullptr);
      final decode = a.allocate<Float>(4)..asTypedList(4).setAll(0, [0, 1, 0, 1]);
      final shouldInterpolate = true;
      final intent = cg.CGColorRenderingIntent.kCGRenderingIntentDefault;
      final cgImage = _coregraphicsBindings.CGImageCreate(
        width,
        height,
        bitsPerComponent,
        bitsPerPixel,
        bytesPerRow,
        colorSpace,
        bitmapInfo,
        provider,
        decode.cast(),
        shouldInterpolate,
        intent,
      );

      final ciImage = ci.CIImage.imageWithCGImage_(cgImage.cast());
      final dict =
          NSMutableDictionary.dictionary()
            ..setObject_forKey_(_coreimageBindings.kCIContextUseSoftwareRenderer, NSNumber()..initWithBool_(false));
      final context = ci.CIContext.contextWithOptions_(dict);
      final scaleX = targetDimensions.width / dimensions.width;
      final scaleY = targetDimensions.height / dimensions.height;
      final transform =
          a<ci.CGAffineTransform>()
            ..ref.a = scaleX
            ..ref.b = 0
            ..ref.c = 0
            ..ref.d = scaleY
            ..ref.tx = 0
            ..ref.ty = 0;
      final scaledImage = ciImage.imageByApplyingTransform_(transform.ref);

      final renderedImage = context.createCGImage_fromRect_(scaledImage, scaledImage.extent);
      if (renderedImage == nullptr) {
        throw Exception('Failed to create CGImage');
      }

      // get the bitmap data from the rendered image
      final bitmapData = _coregraphicsBindings.CGImageGetDataProvider(renderedImage.cast());
      if (bitmapData == nullptr) {
        throw Exception('Failed to get bitmap data from CGImage');
      }
      final data = _coregraphicsBindings.CGDataProviderCopyData(bitmapData);
      if (data == nullptr) {
        throw Exception('Failed to copy data from CGDataProvider');
      }
      _coregraphicsBindings.CGImageRelease(cgImage.cast());
      _coregraphicsBindings.CGImageRelease(renderedImage.cast());
      _coregraphicsBindings.CGDataProviderRelease(bitmapData.cast());
      return data;
    });
  }

  // WebPDemuxer* demux = WebPDemux(&webp_data);

  // uint32_t width = WebPDemuxGetI(demux, WEBP_FF_CANVAS_WIDTH);
  // uint32_t height = WebPDemuxGetI(demux, WEBP_FF_CANVAS_HEIGHT);
  // // ... (Get information about the features present in the WebP file).
  // uint32_t flags = WebPDemuxGetI(demux, WEBP_FF_FORMAT_FLAGS);

  // // ... (Iterate over all frames).
  // WebPIterator iter;
  // if (WebPDemuxGetFrame(demux, 1, &iter)) {
  //   do {
  //     // ... (Consume 'iter'; e.g. Decode 'iter.fragment' with WebPDecode(),
  //     // ... and get other frame properties like width, height, offsets etc.
  //     // ... see 'struct WebPIterator' below for more info).
  //   } while (WebPDemuxNextFrame(&iter));
  //   WebPDemuxReleaseIterator(&iter);
  // }

  // // ... (Extract metadata).
  // WebPChunkIterator chunk_iter;
  // if (flags & ICCP_FLAG) WebPDemuxGetChunk(demux, "ICCP", 1, &chunk_iter);
  // // ... (Consume the ICC profile in 'chunk_iter.chunk').
  // WebPDemuxReleaseChunkIterator(&chunk_iter);
  // if (flags & EXIF_FLAG) WebPDemuxGetChunk(demux, "EXIF", 1, &chunk_iter);
  // // ... (Consume the EXIF metadata in 'chunk_iter.chunk').
  // WebPDemuxReleaseChunkIterator(&chunk_iter);
  // if (flags & XMP_FLAG) WebPDemuxGetChunk(demux, "XMP ", 1, &chunk_iter);
  // // ... (Consume the XMP metadata in 'chunk_iter.chunk').
  // WebPDemuxReleaseChunkIterator(&chunk_iter);
  // WebPDemuxDelete(demux);

  WebPDataWrapper resizeWebPImage(
    Uint8List bytes,
    Dimensions dimensions,
    Dimensions targetDimensions, {
    double quality = 100,
  }) {
    return using((a) {
      final data = WebPDataWrapper.from(bytes, allocator: a);
      final demux = _webpBindings.WebPDemuxInternal(
        data.webPDataPtr,
        WebPDemuxState.WEBP_DEMUX_PARSING_HEADER.value,
        nullptr,
        _webpBindings.WebPGetDecoderVersion(),
      ).check('WebPDemux');
      final mux = _webpBindings.WebPNewInternal(_webpBindings.WebPGetDecoderVersion()).check('WebPMux');
      final width = _webpBindings.WebPDemuxGetI(demux, WebPFormatFeature.WEBP_FF_CANVAS_WIDTH);
      final height = _webpBindings.WebPDemuxGetI(demux, WebPFormatFeature.WEBP_FF_CANVAS_HEIGHT);

      final widthPtr = a<Int>()..value = width;
      final heightPtr = a<Int>()..value = height;
      final iter = a<WebPIterator>();

      final output = a<Pointer<Uint8>>();
      final bitstream = a<WebPData>();

      if (_webpBindings.WebPDemuxGetFrame(demux, 1, iter).asBool) {
        do {
          final frame = iter.ref.fragment;
          final decoded = _webpBindings.WebPDecodeRGBA(
            frame.bytes,
            frame.size,
            widthPtr,
            heightPtr,
          ).check('Decoded RGBA frame');

          final resized = _resizeFrame(
            decoded,
            size: frame.size,
            dimensions: (width: width, height: height),
            targetDimensions: targetDimensions,
          );
          _webpBindings.WebPFree(decoded.cast());

          final size = _webpBindings.WebPEncodeRGBA(
            _coregraphicsBindings.CFDataGetBytePtr(resized).cast(),
            targetDimensions.width,
            targetDimensions.height,
            4 * targetDimensions.width,
            quality,
            output,
          ).check(name: 'WebPEncodeRGBA.size');

          _coregraphicsBindings.CFRelease(resized.cast());

          bitstream.ref.size = size;
          bitstream.ref.bytes = output.value;
          final frameInfo =
              a<WebPMuxFrameInfo>()
                ..ref.bitstream = bitstream.ref
                ..ref.duration = iter.ref.duration
                ..ref.x_offset = iter.ref.x_offset
                ..ref.y_offset = iter.ref.y_offset
                ..ref.dispose_methodAsInt = iter.ref.dispose_methodAsInt
                ..ref.blend_methodAsInt = iter.ref.blend_methodAsInt;

          _webpBindings.WebPMuxPushFrame(mux, frameInfo, true.asInt).check('WebPMuxPushFrame');
          _webpBindings.WebPFree(output.value.cast());
        } while (_webpBindings.WebPDemuxNextFrame(iter).asBool);
        _webpBindings.WebPDemuxReleaseIterator(iter);
      } else {
        throw Exception('Failed to get frame from WebP image');
      }
      //! We use calloc here to make sure it stays alive until we explicitly free it
      final outputWebPData = calloc<WebPData>();
      _webpBindings.WebPMuxAssemble(mux, outputWebPData).check('WebPMuxAssemble');
      _webpBindings.WebPMuxDelete(mux);
      _webpBindings.WebPDemuxDelete(demux);

      return WebPDataWrapper.innerOwnedByWebP(outputWebPData, allocator: calloc);
    });
  }
}

class CFData implements Finalizable {
  static final _cfReleasePtr = _dylib.lookup<NativeFunction<Void Function(cg.CFTypeRef)>>('CFRelease');
  static final _finalizer = NativeFinalizer(_cfReleasePtr);
  final cg.CFDataRef _ptr;

  factory CFData(cg.CFDataRef ptr) {
    final data = CFData._(ptr);
    _finalizer.attach(data, ptr.cast(), detach: true);
    return data;
  }

  CFData._(this._ptr);

  cg.CFDataRef get cfDataRef {
    return _ptr;
  }

  Uint8List get asUint8List {
    return _coregraphicsBindings.CFDataGetBytePtr(
      _ptr,
    ).cast<Uint8>().asTypedList(_coregraphicsBindings.CFDataGetLength(_ptr));
  }

  Pointer<Uint8> get bytePtr {
    return _coregraphicsBindings.CFDataGetBytePtr(_ptr).cast<Uint8>();
  }

  int get length {
    return _coregraphicsBindings.CFDataGetLength(_ptr);
  }
}

class Buffer implements Finalizable {
  static final _callocFinalizer = NativeFinalizer(calloc.nativeFree);
  static final _mallocFinalizer = NativeFinalizer(malloc.nativeFree);

  final Pointer<Uint8> ptr;
  final int length;
  final Allocator allocator;

  factory Buffer(Pointer<Uint8> ptr, {required int length, required Allocator allocator}) {
    final buffer = Buffer._(ptr, length: length, allocator: allocator);
    _getFinalizer(allocator).attach(buffer, ptr.cast(), externalSize: length);
    return buffer;
  }
  factory Buffer.allocate(Allocator allocator, int length) {
    final ptr = allocator.allocate<Uint8>(length);
    final buffer = Buffer._(ptr, length: length, allocator: allocator);
    _getFinalizer(allocator).attach(buffer, ptr.cast(), externalSize: length);
    return buffer;
  }

  factory Buffer.from(Uint8List data, {required Allocator allocator}) {
    final length = data.length;
    final ptr = allocator.allocate<Uint8>(length);
    final buffer = Buffer._(ptr, length: length, allocator: allocator);
    _getFinalizer(allocator).attach(buffer, ptr.cast(), externalSize: length);
    ptr.asTypedList(length).setAll(0, data);
    return buffer;
  }

  Buffer._(this.ptr, {required this.length, required this.allocator});

  Buffer copy() {
    return Buffer.from(asTypedList, allocator: allocator);
  }

  Uint8List get asTypedList {
    return ptr.asTypedList(length);
  }

  static NativeFinalizer _getFinalizer(Allocator allocator) {
    if (allocator == calloc) {
      return _callocFinalizer;
    } else if (allocator == malloc) {
      return _mallocFinalizer;
    } else {
      throw ArgumentError('Allocator must be either calloc or malloc');
    }
  }

  Pointer<T> cast<T extends NativeType>() {
    return ptr.cast<T>();
  }
}

class WebPDataWrapper implements Finalizable {
  static final _callocFinalizer = NativeFinalizer(calloc.nativeFree);
  static final _mallocFinalizer = NativeFinalizer(malloc.nativeFree);
  static final _webpFinalizer = NativeFinalizer(_webPFreePtr);
  final Pointer<WebPData> webPDataPtr;

  factory WebPDataWrapper.from(Uint8List data, {required Allocator allocator}) {
    final length = data.length;
    final ptr = allocator.allocate<Uint8>(length);
    final webPDataPtr = allocator<WebPData>();
    webPDataPtr.ref.size = length;
    webPDataPtr.ref.bytes = ptr;
    ptr.asTypedList(length).setAll(0, data);

    final webpData = WebPDataWrapper._(webPDataPtr);

    _getFinalizer(allocator).attach(webpData, ptr.cast(), externalSize: length);
    _getFinalizer(allocator).attach(webpData, webPDataPtr.cast(), externalSize: sizeOf<WebPData>());

    return webpData;
  }

  factory WebPDataWrapper.innerOwnedByWebP(Pointer<WebPData> webPDataPtr, {required Allocator allocator}) {
    final webpData = WebPDataWrapper._(webPDataPtr);
    _webpFinalizer.attach(webpData, webPDataPtr.ref.bytes.cast(), externalSize: webPDataPtr.ref.size);
    _getFinalizer(allocator).attach(webpData, webPDataPtr.cast(), externalSize: sizeOf<WebPData>());
    return webpData;
  }

  WebPDataWrapper._(this.webPDataPtr);

  static NativeFinalizer _getFinalizer(Allocator allocator) {
    if (allocator == calloc) {
      return _callocFinalizer;
    } else if (allocator == malloc) {
      return _mallocFinalizer;
    } else {
      throw ArgumentError('Allocator must be either calloc or malloc');
    }
  }

  Uint8List get asTypedList {
    return webPDataPtr.ref.bytes.asTypedList(webPDataPtr.ref.size);
  }
}

final _webPFreePtr = _dylib.lookup<NativeFunction<Void Function(Pointer<Void>)>>('WebPFree');

class WebPDecodedRGBAFrame implements Finalizable {
  static final _finalizer = NativeFinalizer(_webPFreePtr);
  final Pointer<Uint8> data;
  final int length;
  final int width;
  final int height;

  factory WebPDecodedRGBAFrame(Pointer<Uint8> ptr, {required int length, required int width, required int height}) {
    final frame = WebPDecodedRGBAFrame._(ptr, width: width, height: height, length: length);
    _finalizer.attach(frame, ptr.cast(), detach: true);
    return frame;
  }

  WebPDecodedRGBAFrame._(this.data, {required this.width, required this.height, required this.length});

  Uint8List get asUint8List {
    return data.asTypedList(width * height * 4);
  }
}

class WebPEncodedRGBAFrame implements Finalizable {
  static final _finalizer = NativeFinalizer(_webPFreePtr);
  final Pointer<Uint8> data;
  final int length;
  final int width;
  final int height;

  factory WebPEncodedRGBAFrame(Pointer<Uint8> ptr, {required int length, required int width, required int height}) {
    final frame = WebPEncodedRGBAFrame._(ptr, width: width, height: height, length: length);
    _finalizer.attach(frame, ptr.cast(), detach: true);
    return frame;
  }
  WebPEncodedRGBAFrame._(this.data, {required this.width, required this.height, required this.length});

  Uint8List get asUint8List {
    return data.asTypedList(length);
  }
}

extension PtrExt<T extends NativeType> on Pointer<T> {
  Pointer<T> check([String? name]) {
    if (this == nullptr) {
      throw Exception('Null pointer exception on ${name ?? 'object'} of type $T');
    }
    return this;
  }
}

extension WebpMuxErrorExt on WebPMuxError {
  String get name => switch (this) {
    WebPMuxError.WEBP_MUX_OK => 'WEBP_MUX_OK',
    WebPMuxError.WEBP_MUX_INVALID_ARGUMENT => 'WEBP_MUX_INVALID_ARGUMENT',
    WebPMuxError.WEBP_MUX_MEMORY_ERROR => 'WEBP_MUX_MEMORY_ERROR',
    WebPMuxError.WEBP_MUX_NOT_FOUND => 'WEBP_MUX_NOT_FOUND',
    WebPMuxError.WEBP_MUX_BAD_DATA => 'WEBP_MUX_BAD_DATA',
    WebPMuxError.WEBP_MUX_NOT_ENOUGH_DATA => 'WEBP_MUX_NOT_ENOUGH_DATA',
  };
  void check([String? context]) {
    if (this != WebPMuxError.WEBP_MUX_OK) {
      throw Exception("Encountered error: $name${context != null ? ' in $context' : ''}");
    }
  }
}

// VP8_STATUS_OK(0),
// VP8_STATUS_OUT_OF_MEMORY(1),
// VP8_STATUS_INVALID_PARAM(2),
// VP8_STATUS_BITSTREAM_ERROR(3),
// VP8_STATUS_UNSUPPORTED_FEATURE(4),
// VP8_STATUS_SUSPENDED(5),
// VP8_STATUS_USER_ABORT(6),
// VP8_STATUS_NOT_ENOUGH_DATA(7);
void checkVP8(int value, [String? context]) {
  final text = switch (value) {
    0 => 'VP8_STATUS_OK',
    1 => 'VP8_STATUS_OUT_OF_MEMORY',
    2 => 'VP8_STATUS_INVALID_PARAM',
    3 => 'VP8_STATUS_BITSTREAM_ERROR',
    4 => 'VP8_STATUS_UNSUPPORTED_FEATURE',
    5 => 'VP8_STATUS_SUSPENDED',
    6 => 'VP8_STATUS_USER_ABORT',
    7 => 'VP8_STATUS_NOT_ENOUGH_DATA',
    _ => 'Unknown VP8 status: $value',
  };
  if (value != 0) {
    throw Exception("Encountered error: $text${context != null ? ' in $context' : ''}");
  }
}

extension CBoolExt on int {
  bool get asBool => this != 0;

  int get checked {
    if (!asBool) {
      throw Exception('Expected true, but got false');
    }
    return this;
  }

  int check({String? message, String? name}) {
    if (!asBool) {
      if (message != null) {
        throw Exception(message);
      } else if (name != null) {
        throw Exception('Expected $name to be true, but got false');
      } else {
        throw Exception('Expected true, but got false');
      }
    }
    return this;
  }
}

extension BoolAsInt on bool {
  int get asInt => this ? 1 : 0;
}
