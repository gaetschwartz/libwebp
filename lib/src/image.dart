import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libwebp/libwebp.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart' as bindings;
import 'package:libwebp/src/utils.dart';
import 'package:meta/meta.dart';

typedef WebPDecoderFinalizable = ({
  Arena arena,
  Pointer<bindings.WebPAnimDecoder> decoder
});

class WebPImage {
  final FfiByteData _data;
  final Allocator _alloc;
  final Pointer<bindings.WebPAnimDecoder> _decoder;

  late final _infoPtr = _alloc<bindings.WebPAnimInfo>();

  static final _finalizer = Finalizer<WebPDecoderFinalizable>((data) {
    data.arena.releaseAll();
    libwebp.WebPAnimDecoderDelete(data.decoder);
  });

  factory WebPImage(Uint8List data) {
    final arena = Arena(calloc);

    final d = FfiByteData.fromTypedList(data, arena);
    final dec = _animDecoder(arena, d);
    final wrapper = WebPImage._(data: d, alloc: arena, decoder: dec);
    _finalizer.attach(
      wrapper,
      (arena: arena, decoder: dec),
      detach: wrapper,
    );
    return wrapper;
  }

  WebPImage._({
    required FfiByteData data,
    required Allocator alloc,
    required Pointer<bindings.WebPAnimDecoder> decoder,
  })  : _data = data,
        _alloc = alloc,
        _decoder = decoder;

  bindings.WebPAnimInfo get info {
    if (libwebp.WebPAnimDecoderGetInfo(_decoder, _infoPtr) == 0) {
      throw LibWebpException('Failed to get info.');
    }
    return _infoPtr.ref;
  }

  Iterable<WebPFrame> get frames => WebPImageFramesIterable(this);

  double get fps => 1000 * info.frame_count / frames.last.timestamp;

  int get averageFrameDuration => frames.last.timestamp ~/ info.frame_count;
}

class WebPFrame {
  final int timestamp;
  @internal
  final Pointer<Uint8> data;
  final int width;
  final int height;

  WebPFrame({
    required this.timestamp,
    required this.data,
    required this.width,
    required this.height,
  });

  Uint8List encode({
    double quality = 100,
    int? width,
    int? height,
  }) =>
      using((Arena alloc) {
        final w = width ?? this.width;
        final h = height ?? this.height;
        final out = alloc<Pointer<Uint8>>();
        final size = libwebp.WebPEncodeRGBA(
          data,
          w,
          h,
          w * 4,
          quality,
          out,
        );
        if (size == 0) {
          throw LibWebpException('Failed to encode frame.');
        }
        return Uint8List.fromList(out.value.asTypedList(size));
      });
}

class WebPImageFramesIterable extends Iterable<WebPFrame> {
  final WebPImage _image;

  WebPImageFramesIterable(this._image);

  @override
  Iterator<WebPFrame> get iterator => WebPImageFramesIterator(_image);
}

class WebPImageFramesIterator implements Iterator<WebPFrame> {
  WebPFrame? _current;

  static final _finalizer = Finalizer<Arena>(
    (data) => data.releaseAll(),
  );

  final WebPImage _image;
  final Pointer<bindings.WebPAnimDecoder> _decoder;
  final Allocator _alloc;

  WebPImageFramesIterator._(this._image, this._alloc)
      : _decoder = _animDecoder(calloc, _image._data);

  factory WebPImageFramesIterator(WebPImage image) {
    final alloc = Arena(calloc);
    final iterator = WebPImageFramesIterator._(image, alloc);
    _finalizer.attach(iterator, alloc, detach: iterator);
    return iterator;
  }

  @override
  WebPFrame get current => _current!;

  late final _info = _image.info;

  @override
  bool moveNext() {
    final frame = _alloc<Pointer<Uint8>>();
    final ms = _alloc<Int>();
    if (libwebp.WebPAnimDecoderGetNext(_decoder, frame, ms) == 0) {
      return false;
    }
    _current = WebPFrame(
      timestamp: ms.value,
      data: frame.value,
      width: _info.canvas_width,
      height: _info.canvas_height,
    );
    return true;
  }
}

enum WebPPreset {
  default_(bindings.WebPPreset.WEBP_PRESET_DEFAULT),
  picture(bindings.WebPPreset.WEBP_PRESET_PICTURE),
  photo(bindings.WebPPreset.WEBP_PRESET_PHOTO),
  drawing(bindings.WebPPreset.WEBP_PRESET_DRAWING),
  icon(bindings.WebPPreset.WEBP_PRESET_ICON),
  text(bindings.WebPPreset.WEBP_PRESET_TEXT);

  final int value;

  const WebPPreset(this.value);
}

Pointer<bindings.WebPAnimDecoder> _animDecoder(
  Allocator alloc,
  FfiByteData data,
) {
  final webpData = data.toWebPData(alloc);

  final opt = alloc<bindings.WebPAnimDecoderOptions>();
  libwebp.WebPAnimDecoderOptionsInitInternal(
    opt,
    bindings.WEBP_DEMUX_ABI_VERSION,
  );
  opt.ref.color_mode = bindings.WEBP_CSP_MODE.MODE_RGBA;
  opt.ref.use_threads = 1;

  final decoder = libwebp.WebPAnimDecoderNewInternal(
    webpData,
    opt,
    bindings.WEBP_DEMUX_ABI_VERSION,
  );
  if (decoder == nullptr) {
    throw LibWebpException('Failed to create WebPAnimDecoder.');
  }

  return decoder;
}

class WebPAnimationTiming {
  final int value;
  const WebPAnimationTiming(this.value);

  WebPAnimationTiming.fps(double fps) : value = 1000 ~/ fps;
}
