import 'dart:ffi';
import 'dart:typed_data';

import 'package:libwebp/libwebp_generated_bindings.dart';

// ignore: non_constant_identifier_names

class FfiByteData {
  final Pointer<Uint8> ptr;
  final int size;

  FfiByteData.ffi({required this.ptr, required this.size});

  factory FfiByteData.allocate(Allocator allocator, int size) {
    return FfiByteData.ffi(
      ptr: allocator.call<Uint8>(size),
      size: size,
    );
  }

  factory FfiByteData.fromTypedList(Uint8List list, Allocator allocator) {
    final data = FfiByteData.ffi(
      ptr: allocator.call<Uint8>(list.length),
      size: list.length,
    );
    data.ptr.asTypedList(list.length).setAll(0, list);
    return data;
  }

  List<int> get asList => ptr.asTypedList(size);

  void setAll(int index, Uint8List list) {
    ptr.asTypedList(size).setAll(index, list);
  }

  Pointer<WebPData> toWebPData(Allocator allocator) {
    final data = allocator<WebPData>();
    data.ref.size = size;
    data.ref.bytes = ptr;
    return data;
  }
}

extension AllocatorX on Allocator {
  FfiByteData byteData(int size) =>
      FfiByteData.ffi(ptr: call<Uint8>(size), size: size);

  FfiByteData fromTypedList(Uint8List list) =>
      FfiByteData.fromTypedList(list, this);
}

extension RGBAX on WebPRGBABuffer {
  String toDetailedString() {
    return '''
WebPRGBABuffer:
  rgba (ptr): $rgba
  rgba (list): ${asList.take(16).hexString}
  size: $size
  stride: $stride
''';
  }

  Uint8List get asList => rgba.asTypedList(size);
}

extension IterableIntX on Iterable<int> {
  String get hexString {
    return map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}
