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

  // Regression: `reduceFps` used `dur * divisor` per kept frame, which only
  // preserves total animation time when every source frame has the same
  // duration. For variable-FPS input the previous behaviour silently
  // shortened the animation.
  group('reduceFps preserves total duration for variable-FPS input', () {
    test('divisor=2 over alternating 100ms/500ms', () {
      final source = ListWebPAnimationTiming(const [
        Duration(milliseconds: 100),
        Duration(milliseconds: 500),
        Duration(milliseconds: 100),
        Duration(milliseconds: 500),
      ]);
      final reduced = source.reduceFps(2);

      expect(reduced.totalDuration, source.totalDuration);
      expect(reduced.frames.toList(), const [
        Duration(milliseconds: 600), // 100 + 500
        Duration.zero,
        Duration(milliseconds: 600), // 100 + 500
        Duration.zero,
      ]);
    });

    test('divisor=3 over mixed durations with tail < divisor', () {
      // 5 frames, divisor=3 — last kept index (i=3) only has 2 frames to absorb.
      final source = ListWebPAnimationTiming(const [
        Duration(milliseconds: 40),
        Duration(milliseconds: 120),
        Duration(milliseconds: 40),
        Duration(milliseconds: 200),
        Duration(milliseconds: 80),
      ]);
      final reduced = source.reduceFps(3);

      expect(reduced.totalDuration, source.totalDuration);
      expect(reduced.frames.toList(), const [
        Duration(milliseconds: 200), // 40 + 120 + 40
        Duration.zero,
        Duration.zero,
        Duration(milliseconds: 280), // 200 + 80 (tail, < divisor)
        Duration.zero,
      ]);
    });

    test('divisor=1 is a no-op', () {
      final source = ListWebPAnimationTiming(const [
        Duration(milliseconds: 33),
        Duration(milliseconds: 67),
      ]);
      final reduced = source.reduceFps(1);

      expect(identical(reduced, source), isTrue);
    });
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
