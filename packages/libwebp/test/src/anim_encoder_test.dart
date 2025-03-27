import 'package:libwebp/libwebp.dart';
import 'package:test/test.dart';

void main() {
  const originalFps = 25.0;
  group('timings $originalFps fps', () {
    const framDur = Duration(milliseconds: 1000 ~/ originalFps);
    final List<Duration> list = List.filled(1000, framDur);
    final timings = ListWebPAnimationTiming(list);

    test('fps', () {
      expect(timings.fps, originalFps);
    });

    for (var i = 1; i < 10; i++) {
      test('reduceFps by $i', () {
        final WebPAnimationTiming reduced = timings.reduceFps(i);
        expect(reduced.frames.length, list.length);
        expect(reduced.frames.nonZero.length, (list.length / i).ceil());
        expect(reduced.fps, closeTo(originalFps / i, 0.1));
        expect(
          reduced.totalDuration,
          closeToDur(timings.totalDuration, framDur * i),
        );
      });
    }
  });
}

/// Returns a matcher which matches if the match argument is within [delta]
/// of some [value].
///
/// In other words, this matches if the match argument is greater than
/// than or equal [value]-[delta] and less than or equal to [value]+[delta].
Matcher closeToDur(
  Duration value, [
  Duration delta = const Duration(milliseconds: 1),
]) =>
    predicate<Duration>((d) => (d - value).abs() <= delta, 'close to $value');
