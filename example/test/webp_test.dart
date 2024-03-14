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
      path.join(Directory.systemTemp.path, 'libwebp_flutter_libs', 'tests'),
    );
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

    final webpImage = WebPImage(xdding);
    print('frames: ${webpImage.frames.map((e) => e.timestamp).toList()}');
    print('frameDuration: ${webpImage.averageFrameDuration}');
    final encoder = WebPAnimEncoder(
      width: 512,
      height: 512,
      options: const WebPAnimEncoderOptions(verbose: true),
    );

    encoder.add(webpImage, webpImage.timings);

    final encoded = encoder.assemble();

    final decoded = WebPImage(encoded);
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

    final encoder = WebPAnimEncoder(
      width: 512,
      height: 512,
      config: config,
      options: const WebPAnimEncoderOptions(verbose: true),
    );

    const webPAnimationTimingAllFrames = WebPAnimationTimingAllFrames(
      Duration(milliseconds: 100),
    );

    encoder.add(WebPImage(xdd), webPAnimationTimingAllFrames);
    encoder.add(WebPImage(xdd), webPAnimationTimingAllFrames);

    expect(encoder.frameCount, 2);

    final encoded = encoder.assemble();

    final decoded = WebPImage(encoded);
    expect(decoded.info.canvas_width, 512);
    expect(decoded.info.canvas_height, 512);
    // expect(decoded.info.frame_count, 2);

    final file = temp.file('xdd-512x512-encoder.webp');
    await file.writeAsBytes(encoded);
    print('xdd-512x512-encoder.webp: ${file.path}');
  });

  test('resize big file', () async {
    final big = await load('hackerCD.webp');
    final webPImage = WebPImage(big);

    final enc1 = WebPAnimEncoder(
      width: 512,
      height: 512,
      options: const WebPAnimEncoderOptions(verbose: true),
    );

    enc1.add(webPImage, webPImage.timings);

    final encoded1 = enc1.assemble();

    final cfg = WebPConfig(quality: 0);
    cfg.threadLevel = 1;
    cfg.method = 6;
    // cfg.targetSize = 500 * 1024 ~/ webPImage.info.frame_count;

    final enc2 = WebPAnimEncoder(
      width: 512,
      height: 512,
      options: const WebPAnimEncoderOptions(verbose: true),
      config: cfg,
    );

    enc2.add(webPImage, webPImage.timings);

    final encoded2 = enc2.assemble();

    expect(encoded1.length, greaterThan(encoded2.length));

    print('big: ${humanReadableSize(big.length)}');
    print('encoded1: ${humanReadableSize(encoded1.length)}');
    print('encoded2: ${humanReadableSize(encoded2.length)}');

    final file1 = temp.file('hackerCD-512x512-encoder1.webp');
    await file1.writeAsBytes(encoded1);
    print('hackerCD-512x512-encoder1.webp: ${file1.path}');
    final file2 = temp.file('hackerCD-512x512-encoder2.webp');
    await file2.writeAsBytes(encoded2);
    print('hackerCD-512x512-encoder2.webp: ${file2.path}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('WebpImage', () async {
    final xdd = await load('xdding.webp');
    final img = WebPImage(xdd);
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

String humanReadableSize(int size) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  var s = size.toDouble();
  while (s > 1024) {
    s /= 1024;
    i++;
  }
  return '${s.toStringAsFixed(2)} ${units[i]}';
}
