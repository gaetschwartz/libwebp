import 'dart:ffi';
import 'dart:typed_data';

import 'package:libwebp/libwebp_generated_bindings.dart';

class Uint8Data {
  final Pointer<Uint8> ptr;
  final int length;

  Uint8Data({required this.ptr, required this.length});

  List<int> get asList => ptr.asTypedList(length);
}

extension AllocatorX on Allocator {
  Uint8Data uint8Array(int length) {
    final pointer = call<Uint8>(length);
    return Uint8Data(ptr: pointer, length: length * sizeOf<Uint8>());
  }
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
