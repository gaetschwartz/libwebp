import 'dart:ffi';

import 'package:libwebp/src/libwebp_generated_bindings.dart';
import 'package:libwebp/src/utils.dart';
import 'package:test/test.dart';

void main() {
  test('checkAlloc', () {
    expect(
      () => checkAlloc<WebPAnimDecoder>(nullptr, 'Failed to allocate.'),
      throwsA(
        isA<LibWebPAllocException>()
            .having((e) => e.objectName, 'objectName', 'WebPAnimDecoder'),
      ),
    );
  });
}
