// ignore_for_file: avoid_print, do_not_use_environment

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:libwebp/src/libwebp.dart';
import 'package:libwebp/src/libwebp_generated_bindings.dart' as bindings;

const libWebpDebug = bool.fromEnvironment('dev.gaetans.libwebp.debug');

final callocFinalizer = TypedFinalizer<Void>(
  calloc.nativeFree,
  debugName: 'callocFinalizer',
);

final decoderFinalizer = TypedFinalizer<bindings.WebPAnimDecoder>(
  _webPAnimDecoderDeletePtr,
  debugName: 'WebPAnimDecoderFinalizer',
);

final encoderFinalizer = TypedFinalizer<bindings.WebPAnimEncoder>(
  _webPAnimEncoderDeletePtr,
  debugName: 'WebPAnimEncoderFinalizer',
);

final webpFreeFinalizer = TypedFinalizer<Void>(
  _webpFreePtr,
  debugName: 'WebPFreeFinalizer',
);

final muxFinalizer = TypedFinalizer<bindings.WebPMux>(
  _muxDeletePtr,
  debugName: 'WebPMuxFinalizer',
);

final iteratorFinalizer = TypedFinalizer<bindings.WebPIterator>(
  _iteratorReleasePtr,
  debugName: 'WebPIteratorFinalizer',
);

final _webPAnimDecoderDeletePtr =
    rawBindings.lookup<NativeFunction<bindings.NativeWebPAnimDecoderDelete>>(
  'WebPAnimDecoderDelete',
);

final _webPAnimEncoderDeletePtr =
    rawBindings.lookup<NativeFunction<bindings.NativeWebPAnimEncoderDelete>>(
  'WebPAnimEncoderDelete',
);

final _webpFreePtr =
    rawBindings.lookup<NativeFunction<bindings.NativeWebPFree>>(
  'WebPFree',
);

final _muxDeletePtr =
    rawBindings.lookup<NativeFunction<bindings.NativeWebPMuxDelete>>(
  'WebPMuxDelete',
);

final _iteratorReleasePtr =
    rawBindings.lookup<NativeFunction<bindings.NativeWebPDemuxReleaseIterator>>(
  'WebPDemuxReleaseIterator',
);

abstract class TypedFinalizer<T extends NativeType> {
  void attach<N extends Finalizable>(
    N obj,
    Pointer<T> ptr, {
    N? detach,
  });

  void detach<N extends Finalizable>(N obj);

  factory TypedFinalizer(
    Pointer<NativeFunction<Void Function(Pointer<T>)>> finalizerFn, {
    int? externalSize,
    String? debugName,
  }) =>
      _TypedFinalizerImpl(
        finalizerFn,
        externalSize: externalSize,
        debugName: debugName,
      );

  factory TypedFinalizer.noop(
    // ignore: avoid_unused_constructor_parameters
    Pointer<NativeFunction<Void Function(Pointer<T>)>> finalizerFn, {
    // ignore: avoid_unused_constructor_parameters
    int? externalSize,
    String? debugName,
  }) =>
      _NoopFinalizer(debugName: debugName);
}

class _TypedFinalizerImpl<T extends NativeType> implements TypedFinalizer<T> {
  final Pointer<NativeFunction<Void Function(Pointer<T>)>> finalizerFn;
  final NativeFinalizer finalizer;
  final int? externalSize;
  final String? debugName;

  _TypedFinalizerImpl(
    this.finalizerFn, {
    this.externalSize,
    this.debugName,
  }) : finalizer = NativeFinalizer(finalizerFn.cast());

  @override
  void attach<N extends Finalizable>(
    N obj,
    Pointer<T> ptr, {
    N? detach,
  }) {
    if (libWebpDebug) {
      print('[$debugName] attach $obj $ptr');
    }
    finalizer.attach(
      obj,
      ptr.cast(),
      detach: detach,
      externalSize: externalSize,
    );
  }

  @override
  void detach<N extends Finalizable>(N obj) {
    if (libWebpDebug) {
      print('[$debugName] detach $obj');
    }
    finalizer.detach(obj);
  }
}

class _NoopFinalizer<T extends NativeType> implements TypedFinalizer<T> {
  final String? debugName;

  const _NoopFinalizer({this.debugName});

  @override
  void attach<N extends Finalizable>(
    N obj,
    Pointer<T> ptr, {
    N? detach,
  }) {
    if (libWebpDebug) {
      print('[noop:$debugName] attach $obj $ptr');
    }
  }

  @override
  void detach<N extends Finalizable>(N obj) {
    if (libWebpDebug) {
      print('[noop:$debugName] detach $obj');
    }
  }
}
