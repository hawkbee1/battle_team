/// A wait, in the largest unit that fits (the symbols are the same in English
/// and French).
String formatWait(Duration wait) => switch (wait) {
  Duration(inHours: >= 1) => '${(wait.inMinutes / 60).toStringAsFixed(1)} h',
  Duration(inMinutes: >= 1) => '${wait.inMinutes} min',
  _ => '${wait.inSeconds} s',
};

/// AP, whole when they are.
String formatAp(double ap) => ap.toStringAsFixed(ap % 1 == 0 ? 0 : 1);

/// The time left until the battle time [until] at [now]; none once it is past
/// or before the host's first message.
Duration remainingOf(Duration until, Duration? now) =>
    now == null || until < now ? Duration.zero : until - now;
