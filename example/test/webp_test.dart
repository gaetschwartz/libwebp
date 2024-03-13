// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:libwebp/libwebp.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

Future<Uint8List> load(String name) async {
  final file = File(path.join('test', 'assets', name));
  return file.readAsBytes();
}

void main() {
  late Directory temp;

  setUpAll(() async {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print('[${record.loggerName}] ${record.level.name}: ${record.message}');
    });
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
    final xdding = await load('xdding.webp');

    final img = resizeWebp(xdding, (width: 512, height: 512));

    await temp.file('xdding-512x512.webp').writeAsBytes(img);
    print('xdding-512x512.webp: ${temp.file('xdding-512x512.webp').path}');

    final resized = image.decodeWebP(img);
    if (resized == null) {
      throw Exception('Failed to decode resized image.');
    }
    expect(resized.width, 512);
    expect(resized.height, 512);
  });

  test('rescale xdding using encoder (animated)', () async {
    final xdding = await load('xdding.webp');

    final webpImage = WebpImage(xdding);
    print('frames: ${webpImage.frames.map((e) => e.timestamp).toList()}');
    final frameDuration = webpImage.averageFrameDuration;
    print('frameDuration: $frameDuration');
    final encoder = WebpEncoder(
      width: 512,
      height: 512,
      timing: WebpAnimationTiming(frameDuration),
      verbose: true,
    );

    encoder.add(webpImage);

    final encoded = encoder.assemble();

    final decoded = WebpImage(encoded);
    expect(decoded.info.canvas_width, 512);
    expect(decoded.info.canvas_height, 512);
    expect(decoded.info.frame_count, 64);

    final file = temp.file('xdding-512x512-encoder.webp');
    await file.writeAsBytes(encoded);
    print('xdding-512x512-encoder.webp: ${file.path}');
  });

  test('static to animated using encoder', () async {
    final xdd = await load('xdd.webp');

    final config = WebPConfig();

    final encoder = WebpEncoder(
      width: 512,
      height: 512,
      timing: const WebpAnimationTiming(100),
      config: config,
      verbose: true,
    );

    encoder.add(WebpImage(xdd));
    encoder.add(WebpImage(xdd));

    expect(encoder.frameCount, 2);

    final encoded = encoder.assemble();

    final decoded = WebpImage(encoded);
    expect(decoded.info.canvas_width, 512);
    expect(decoded.info.canvas_height, 512);
    // expect(decoded.info.frame_count, 2);

    final file = temp.file('xdd-512x512-encoder.webp');
    await file.writeAsBytes(encoded);
    print('xdd-512x512-encoder.webp: ${file.path}');
  });

  test('WebpImage', () async {
    final xdd = await load('xdding.webp');
    final img = WebpImage(xdd);
    final info = img.info;
    expect(info.canvas_width, 228);
    expect(info.canvas_height, 128);
    expect(info.frame_count, 64);
    expect(img.frames.length, 64);
  });
}

extension DirectoryExtension on Directory {
  File file(String name) => File(path.join(this.path, name));
}
