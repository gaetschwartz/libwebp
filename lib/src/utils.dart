import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/src/finalizers.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart' as bindings;

import 'libwebp.dart';

// ignore: non_constant_identifier_names

class FfiByteData implements Finalizable {
  final Pointer<Uint8> ptr;
  final int size;
  bool _disposed = false;

  factory FfiByteData(int size) {
    final ptr = calloc<Uint8>(size);

    final wrapper = FfiByteData._(
      ptr: ptr,
      size: size,
    );

    callocFinalizer.attach(wrapper, ptr.cast(), detach: wrapper);

    return wrapper;
  }

  FfiByteData._({required this.ptr, required this.size});

  factory FfiByteData.fromTypedList(Uint8List list) {
    final data = FfiByteData(list.length);
    data.ptr.asTypedList(list.length).setAll(0, list);
    return data;
  }

  List<int> get asList {
    if (_disposed) {
      throw StateError('FfiByteData already disposed');
    }
    return ptr.asTypedList(size);
  }

  void setAll(int index, Uint8List list) {
    if (_disposed) {
      throw StateError('FfiByteData already disposed');
    }
    ptr.asTypedList(size).setAll(index, list);
  }

  void free() {
    if (_disposed) {
      throw StateError('FfiByteData already disposed');
    }
    calloc.free(ptr);
    callocFinalizer.detach(this);
    _disposed = true;
  }
}

extension IterableIntX on Iterable<int> {
  String get hexString {
    return map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}

int check(
  int res,
  String? message, {
  Pointer<bindings.WebPPicture>? pic,
  Pointer<bindings.WebPAnimEncoder>? encoder,
}) {
  if (res == 0) {
    final picErrorCode =
        pic != null ? Vp8StatusCodeException.of(pic, message) : null;
    final encoderErrorCode =
        encoder != null ? WebPAnimEncoderException.of(encoder, message) : null;
    switch ((picErrorCode, encoderErrorCode)) {
      case (final picError?, null):
        throw picError;
      case (null, final encoderError?):
        throw encoderError;
      case (final picError?, final encoderError?):
        throw MultiLibWebPException([picError, encoderError]);
      case (null, null):
        throw LibWebPException(message ?? 'Unknown error');
    }
  }
  return res;
}

Pointer<T> checkAlloc<T extends NativeType>(Pointer<T> ptr, [String? message]) {
  if (ptr == nullptr) {
    throw LibWebPAllocException(T.toString(), message);
  }
  return ptr;
}

abstract class LibWebPException implements Exception {
  factory LibWebPException(String message) = GenericLibWebPException;
}

class LibWebPAllocException implements LibWebPException {
  final String objectName;
  final String? context;

  LibWebPAllocException(this.objectName, [this.context]);

  @override
  String toString() {
    return 'LiibWebpAllocException: Failed to allocate $objectName: $context';
  }
}

class GenericLibWebPException implements LibWebPException {
  final String message;

  GenericLibWebPException(this.message);

  @override
  String toString() {
    return 'GenericLibWebpException: $message';
  }
}

class MultiLibWebPException implements LibWebPException {
  final List<LibWebPException> exceptions;

  MultiLibWebPException(this.exceptions);

  @override
  String toString() {
    return 'MultiLibWebpException: Multiple exceptions: [${exceptions.join(', ')}]';
  }
}

class WebPAnimEncoderException implements LibWebPException {
  final String error;
  final String? context;

  WebPAnimEncoderException.of(
    Pointer<bindings.WebPAnimEncoder> encoder, [
    this.context,
  ]) : error = libwebp.WebPAnimEncoderGetError(encoder)
            .cast<Utf8>()
            .toDartString();

  @override
  String toString() => 'LibWebpAnimEncoderException: $error: $context';
}

class Vp8StatusCode {
  static const ok = Vp8StatusCode._(bindings.VP8StatusCode.VP8_STATUS_OK, 'ok');
  static const outOfMemory = Vp8StatusCode._(
      bindings.VP8StatusCode.VP8_STATUS_OUT_OF_MEMORY, 'outOfMemory');
  static const invalidParam = Vp8StatusCode._(
      bindings.VP8StatusCode.VP8_STATUS_INVALID_PARAM, 'invalidParam');
  static const bitstreamError = Vp8StatusCode._(
      bindings.VP8StatusCode.VP8_STATUS_BITSTREAM_ERROR, 'bitstreamError');
  static const unsupportedFeature = Vp8StatusCode._(
      bindings.VP8StatusCode.VP8_STATUS_UNSUPPORTED_FEATURE,
      'unsupportedFeature');
  static const suspended =
      Vp8StatusCode._(bindings.VP8StatusCode.VP8_STATUS_SUSPENDED, 'suspended');
  static const userAbort = Vp8StatusCode._(
      bindings.VP8StatusCode.VP8_STATUS_USER_ABORT, 'userAbort');
  static const notEnoughData = Vp8StatusCode._(
      bindings.VP8StatusCode.VP8_STATUS_NOT_ENOUGH_DATA, 'notEnoughData');

  final int value;
  final String name;
  const Vp8StatusCode._(this.value, this.name);
  static const values = [
    ok,
    outOfMemory,
    invalidParam,
    bitstreamError,
    unsupportedFeature,
    suspended,
    userAbort,
    notEnoughData
  ];

  static Vp8StatusCode fromInt(int value) {
    return values.firstWhere(
      (element) => element.value == value,
      orElse: () => Vp8StatusCode._(value, 'unknown'),
    );
  }

  static void check(int code, [String message = '']) {
    if (code != Vp8StatusCode.ok.value) {
      throw Vp8StatusCodeException.fromInt(code, message);
    }
  }
}

class Vp8StatusCodeException implements LibWebPException {
  final Vp8StatusCode code;
  final String? context;

  Vp8StatusCodeException(this.code, this.context);

  Vp8StatusCodeException.fromInt(int code, [this.context])
      : code = Vp8StatusCode.fromInt(code);

  Vp8StatusCodeException.of(Pointer<bindings.WebPPicture> pic, [this.context])
      : code = Vp8StatusCode.fromInt(pic.ref.error_code);

  @override
  String toString() {
    return 'Vp8StatusCodeException: $code: $context';
  }
}

extension BoolInt on int {
  bool get asCBoolean => this != 0;
}

class FinalizableAlloc implements Allocator {
  final _allocations = <Pointer>[];
  final Allocator _allocator;

  FinalizableAlloc([Allocator allocator = calloc]) : _allocator = allocator;

  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    final pointer = _allocator.allocate<T>(byteCount, alignment: alignment);
    _allocations.add(pointer);
    return pointer;
  }

  @override
  void free(Pointer pointer) {
    _allocations.remove(pointer);
    _allocator.free(pointer);
  }

  static final _callocFinalizer = NativeFinalizer(calloc.nativeFree);

  void attachFinalizer<F extends Finalizable>(F instance) {
    for (final e in _allocations) {
      _callocFinalizer.attach(instance, e.cast(), detach: instance);
    }
  }
}

F finalizing<F extends Finalizable>(F Function(FinalizableAlloc a) create) {
  final a = FinalizableAlloc();
  final instance = create(a);
  a.attachFinalizer(instance);

  return instance;
}
