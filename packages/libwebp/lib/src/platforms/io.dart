import 'dart:io';

import 'package:libwebp/src/utils.dart';

extension ReadFileIntoFfiByteDataExtension on File {
  FfiByteData readIntoFfiByteData() {
    final size = lengthSync();
    final data = FfiByteData(size);
    final file = openSync();
    try {
      file.readIntoSync(data.asList);
    } finally {
      file.closeSync();
    }
    return data;
  }
}
