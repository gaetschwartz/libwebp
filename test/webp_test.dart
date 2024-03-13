import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:libwebp/libwebp.dart';
import 'package:path/path.dart' as path;

void main() {
  final xdd = base64Decode(
    'UklGRpQDAABXRUJQVlA4IIgDAABQEACdASo5ACAAPhkIg0EhBn7NAAQAYSygE6ZXsD33bj1YOesxoPEU6Y3PSaabvOVdSfZvAfwS+Z5DNwH1Cwy/3jwB9zeHreCOP/0HiI0o80Hyf/T4YKCDiHhQIqZB0RN0iU7JCTMtTXna2eEfpXJykcq3udU04hwboTkU2juV5s0lUIqlE0IWzKwAAP7/l3fwbHVdt5lcKRUdL5CfGTe07/JoQ8Jdf6AknDnzh78GbWS/nvab9lpb9JEFs4DPYp9hRNEKivgTdOb2fpuMb2ayZ83+LWrv7l+anqA9f/5VkaMkNn34nVh36nKVTqv2Jl0zdpNwpxqc3TmyZdigJFTjQUX4VIiNJNusTm9W4tsW/TZ1fEEvhxoQTiLi/dF2WfUVbC0UkpnBnhUw54iGwRrIHf2Qagna0HG17C9UKSvw/z1eoofJ8QypE+fmW2x3H/SD2fdw2K1rcf/CYpraaX2tTHPdc33luwSz/XqV+r4j/UXCUA6M2U30D2UVT+UBibCB7yCHYkpzcH8RO/An7vr+AYam60PVcKd4nhgtaFaW7HR4Sqzs9uQs8IZc9Y3HCkY1hUvih3GRHw82v4imrACqwqchpST77jOGgZAB49E2eaqgDrfFId0GZrkkxhv4tkAyPHNDa+ZyD6CSgLiEH8VaI8oE9WDI8eWbB7bNsUh+mJ7tfdEdhlr6ZD8u2kT3+wsiFmxl9+AVy/O7VXUNhihdbanO9if+pTMJGfxsgZV3hkue9WzL31twDLUAJ19Xl94QNHcsCSOUYOWc9XD60TineBDObLGHOc1mgiks7SCOx20EYwPvqfQdJS6I2604dGvcES9Sdptel37CEkPfm/lw0Ty7RHa561k4CvbN+Xt5WH/HWdbEx5s5L/JcCVOMyxFkSeLArRgmy+2B56+FLFu5zcUsbQujZtMp89Sq627EUtYfBruPt5PU5HDn8/xOrhGyIe9TWyww2rSatR5NJxch+f56q44+ohNctzXMhkC9yhqHG3/ZuE09VooJeHHrrMepyKLuTYGZSJhVLlj0Ysb9PQp51J0D5RiQ2C/GglQslXySH4hMbS+pDUcdPyCvl+BvImBwyOsTAooTNGooomtB4XEOaaOzno9r0A6LQ5Y75Qc8iHyJs9B/BydrUFCnHlQkv4Qgp4+MqvLtaeZZXT/Ljfci36Q9XHt6RaM40ELB/Sge9mrtFAAA',
  );

  late Directory temp;

  setUpAll(() async {
    temp = Directory(
        path.join(Directory.systemTemp.path, 'libwebp_flutter_libs', 'tests'));
    await temp.create(recursive: true);
    print('temp: ${temp.path}');
  });

  test('xdd right dimensions', () {
    final img = image.decodeWebP(xdd)!;
    expect(img.width, 57);
    expect(img.height, 32);
  });

  test('rescale', () async {
    print('platform: ${Platform.operatingSystem}');
    await temp.file('xdd.webp').writeAsBytes(xdd);

    final img = resizeWebp(xdd, (width: 512, height: 512));

    await temp.file('xdd-512x512.webp').writeAsBytes(img);

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
