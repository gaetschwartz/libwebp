import 'dart:ffi';
import 'dart:io';

import 'package:libwebp/src/utils.dart';

extension ReadFileIntoFfiByteDataExtension on File {
  FfiByteData readIntoFfiByteData(Allocator allocator) {
    final size = lengthSync();
    final data = FfiByteData.allocate(allocator, size);
    final file = openSync();
    try {
      file.readIntoSync(data.asList);
    } finally {
      file.closeSync();
    }
    return data;
  }
}
