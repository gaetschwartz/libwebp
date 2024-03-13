import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:libwebp/libwebp.dart';
import 'package:path/path.dart' as path;

Future<Uint8List> load(String name) async {
  final file = File(path.join('test', 'assets', name));
  return file.readAsBytes();
}

void main() {
  late Directory temp;

  setUpAll(() async {
    temp = Directory(
        path.join(Directory.systemTemp.path, 'libwebp_flutter_libs', 'tests'));
    await temp.create(recursive: true);
    print('temp: ${temp.path}');
  });

  test('xdd right dimensions', () async {
    final img = image.decodeWebP(await load('xdd.webp'))!;
    expect(img.width, 228);
    expect(img.height, 128);
  });

  test('rescale xdd', () async {
    print('platform: ${Platform.operatingSystem}');
    final xdd = await load('xdd.webp');

    final img = resizeWebp(xdd, (width: 512, height: 512));

    await temp.file('xdd-512x512.webp').writeAsBytes(img);

    final resized = image.decodeWebP(img);
    if (resized == null) {
      throw Exception('Failed to decode resized image.');
    }
    expect(resized.width, 512);
    expect(resized.height, 512);
  });

  test('rescale xdding (animated)', () async {
    print('platform: ${Platform.operatingSystem}');
    final xdd = await load('xdding.webp');

    final img = resizeWebp(xdd, (width: 512, height: 512));

    await temp.file('xdding-512x512.webp').writeAsBytes(img);
    print('xdding-512x512.webp: ${temp.file('xdding-512x512.webp').path}');

    final resized = image.decodeWebP(img);
    if (resized == null) {
      throw Exception('Failed to decode resized image.');
    }
    expect(resized.width, 512);
    expect(resized.height, 512);
  });
}

extension DirectoryExtension on Directory {
  File file(String name) => File(path.join(this.path, name));
}
