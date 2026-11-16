// Writes the battle's sounds to assets/sounds/*.wav: `dart run
// tool/sounds/generate_sounds.dart`, from apps/battle_team.
//
// The sounds are synthesized here (noise, sine, saw and triangle waves under
// envelopes), so that they carry no licence and nothing to attribute. They are
// placeholders in the good sense: a recorded sound with the same file name
// replaces one with no change of code (`BattleSounds` names the files).
// The same seed gives the same bytes.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _rate = 22050;

void main() {
  final out = Directory('assets/sounds')..createSync(recursive: true);
  for (final MapEntry(:key, :value) in _sounds().entries) {
    File('${out.path}/$key.wav').writeAsBytesSync(_wav(value));
    stdout.writeln('$key.wav ${(value.length / _rate).toStringAsFixed(2)} s');
  }
}

Map<String, List<double>> _sounds() => {
  'rifle': _rifle(),
  'machine_gun': _machineGun(),
  'cannon': _cannon(),
  'blast': _blast(),
  'foot': _foot(),
  'vehicle': _vehicle(),
  'hit': _hit(),
  'death': _death(),
  'victory': _victory(),
  'defeat': _defeat(),
  'ambience': _ambience(),
};

// Building blocks.

final _random = math.Random(5);

double _noise() => _random.nextDouble() * 2 - 1;

List<double> _silence(double seconds) =>
    List<double>.filled((seconds * _rate).round(), 0);

double _decay(double t, double tau) => math.exp(-t / tau);

/// A one-pole low-pass: [cutoff] at each sample, in Hz.
List<double> _lowPass(List<double> input, double Function(double t) cutoff) {
  final out = List<double>.filled(input.length, 0);
  var y = 0.0;
  for (var i = 0; i < input.length; i++) {
    final a = 1 - math.exp(-2 * math.pi * cutoff(i / _rate) / _rate);
    y += a * (input[i] - y);
    out[i] = y;
  }
  return out;
}

/// Adds [part], scaled by [gain], into [into] from [at] seconds.
void _mix(
  List<double> into,
  List<double> part, {
  double at = 0,
  double gain = 1,
}) {
  final start = (at * _rate).round();
  for (var i = 0; i < part.length && start + i < into.length; i++) {
    into[start + i] += part[i] * gain;
  }
}

/// A sine sweeping from [from] to [to] Hz, fading with [tau].
List<double> _thump(double seconds, double from, double to, double tau) {
  final out = List<double>.filled((seconds * _rate).round(), 0);
  var phase = 0.0;
  for (var i = 0; i < out.length; i++) {
    final t = i / _rate;
    final f = to + (from - to) * _decay(t, tau / 2);
    phase += 2 * math.pi * f / _rate;
    out[i] = math.sin(phase) * _decay(t, tau);
  }
  return out;
}

/// Noise fading with [tau], through a low-pass that closes from [open] to
/// [closed] Hz.
List<double> _burst(
  double seconds,
  double tau, {
  double open = 6000,
  double closed = 600,
}) {
  final raw = [
    for (var i = 0; i < seconds * _rate; i++) _noise() * _decay(i / _rate, tau),
  ];
  return _lowPass(raw, (t) => closed + (open - closed) * _decay(t, tau));
}

/// A tone of [hz] with its first harmonics, under an attack and a release.
List<double> _note(
  double hz,
  double seconds, {
  double attack = 0.01,
  double release = 0.15,
  List<double> harmonics = const [1, 0.5, 0.3, 0.15],
}) {
  final out = List<double>.filled((seconds * _rate).round(), 0);
  for (var i = 0; i < out.length; i++) {
    final t = i / _rate;
    var v = 0.0;
    for (var h = 0; h < harmonics.length; h++) {
      v += harmonics[h] * math.sin(2 * math.pi * hz * (h + 1) * t);
    }
    final up = math.min(1, t / attack);
    final down = math.min(1, (seconds - t) / release);
    out[i] = v * up * down;
  }
  return out;
}

// The sounds.

List<double> _rifle() {
  final s = _silence(0.45);
  _mix(s, _burst(0.45, 0.05, open: 9000, closed: 900));
  _mix(s, _thump(0.2, 150, 55, 0.07), gain: 0.9);
  return _peak(s, 0.8);
}

List<double> _machineGun() {
  final s = _silence(0.16);
  _mix(s, _burst(0.16, 0.025, open: 10000, closed: 1500));
  _mix(s, _thump(0.1, 200, 90, 0.04), gain: 0.5);
  return _peak(s, 0.6);
}

List<double> _cannon() {
  final s = _silence(1.1);
  _mix(s, _thump(1.1, 90, 30, 0.35), gain: 1.2);
  _mix(s, _burst(1.1, 0.18, open: 3500, closed: 200));
  return _peak(s, 0.95);
}

List<double> _blast() {
  final s = _silence(1.5);
  _mix(s, _thump(1.5, 70, 25, 0.5), gain: 1.2);
  _mix(s, _burst(1.5, 0.3, open: 5000, closed: 150), gain: 1.1);
  return _peak(s, 1);
}

List<double> _foot() {
  final s = _silence(0.6);
  for (final at in [0.0, 0.3]) {
    _mix(s, _burst(0.15, 0.03, open: 2500, closed: 250), at: at);
    _mix(s, _thump(0.12, 110, 60, 0.04), at: at, gain: 0.6);
  }
  return _peak(s, 0.5);
}

List<double> _vehicle() {
  const seconds = 1.4;
  final n = (seconds * _rate).round();
  final rumble = List<double>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    final t = i / _rate;
    // A saw at 48 Hz with a wobble: an engine turning over.
    final f = 48 + 3 * math.sin(2 * math.pi * 7 * t);
    final saw = 2 * ((f * t) % 1) - 1;
    final env = math.min(1, t / 0.12) * math.min(1, (seconds - t) / 0.4);
    rumble[i] = (saw * 0.8 + _noise() * 0.3) * env;
  }
  return _peak(_lowPass(rumble, (_) => 220), 0.55);
}

List<double> _hit() {
  final s = _silence(0.3);
  _mix(s, _thump(0.25, 220, 70, 0.06));
  _mix(s, _burst(0.1, 0.015, open: 5000, closed: 800), gain: 0.6);
  return _peak(s, 0.7);
}

List<double> _death() {
  const seconds = 1.0;
  final s = _silence(seconds);
  // A tone that sags and tremors, under a crash.
  final tone = List<double>.filled(s.length, 0);
  var phase = 0.0;
  for (var i = 0; i < tone.length; i++) {
    final t = i / _rate;
    final f = 60 + 260 * _decay(t, 0.25);
    phase += 2 * math.pi * f / _rate;
    tone[i] =
        math.sin(phase) *
        (0.6 + 0.4 * math.sin(2 * math.pi * 18 * t)) *
        _decay(t, 0.35);
  }
  _mix(s, tone);
  _mix(s, _burst(seconds, 0.12, open: 4000, closed: 300), gain: 0.8);
  _mix(s, _thump(0.5, 100, 35, 0.2), gain: 0.8);
  return _peak(s, 0.85);
}

/// C major, rising: C5 E5 G5, then the chord held with C6.
List<double> _victory() {
  final s = _silence(3);
  const notes = [523.25, 659.25, 783.99];
  for (var i = 0; i < notes.length; i++) {
    _mix(s, _note(notes[i], 0.5, release: 0.1), at: i * 0.28);
  }
  for (final hz in [523.25, 659.25, 783.99, 1046.5]) {
    _mix(s, _note(hz, 2, attack: 0.03, release: 1), at: 0.9, gain: 0.7);
  }
  return _peak(s, 0.6);
}

/// A minor line sinking: A4 F4 D4, then A3 and D3 held low.
List<double> _defeat() {
  final s = _silence(3);
  const notes = [440.0, 349.23, 293.66];
  for (var i = 0; i < notes.length; i++) {
    _mix(
      s,
      _note(notes[i], 0.7, release: 0.2, harmonics: const [1, 0.3, 0.1]),
      at: i * 0.5,
    );
  }
  for (final hz in [220.0, 146.83]) {
    _mix(
      s,
      _note(hz, 1.6, attack: 0.05, release: 1, harmonics: const [1, 0.4]),
      at: 1.5,
      gain: 0.8,
    );
  }
  return _peak(s, 0.55);
}

/// The ambience music: a light, bright loop in C major, I V vi IV, 16 s at 120
/// beats a minute: a soft pad under each chord, a low note, a plucked arpeggio
/// that climbs in eighths and a bell on the first beat. The tails of the last
/// chord fold onto the start, so that the loop has no seam.
List<double> _ambience() {
  const chordS = 4.0;
  const eighthS = 0.25;
  const chords = [
    [48, 52, 55], // C
    [43, 47, 50], // G
    [45, 48, 52], // Am
    [41, 45, 48], // F
  ];
  const total = chordS * 4;
  const tail = 3.0;
  final s = _silence(total + tail);
  double hz(int midi) => 440 * math.pow(2, (midi - 69) / 12).toDouble();
  for (var c = 0; c < chords.length; c++) {
    final start = c * chordS;
    final chord = chords[c];
    // The pad: the chord an octave up, swelling in and out, under the rest.
    for (final note in chord) {
      _mix(
        s,
        _note(
          hz(note + 12),
          chordS + 1.2,
          attack: 1,
          release: 1.4,
          harmonics: const [1, 0.25],
        ),
        at: start,
        gain: 0.22,
      );
    }
    // The low note.
    _mix(
      s,
      _note(
        hz(chord.first - 12),
        chordS + 0.4,
        attack: 0.05,
        release: 1.2,
        harmonics: const [1, 0.4],
      ),
      at: start,
      gain: 0.45,
    );
    // The arpeggio: up through the chord and its octave, and back, in eighths.
    final steps = [
      chord[0] + 24,
      chord[1] + 24,
      chord[2] + 24,
      chord[0] + 36,
      chord[2] + 24,
      chord[1] + 24,
      chord[2] + 24,
      chord[1] + 24,
    ];
    for (var i = 0; i < chordS / eighthS; i++) {
      final note = steps[i % steps.length];
      final pluck = _note(
        hz(note),
        1.2,
        attack: 0.004,
        release: 0.05,
        harmonics: const [1, 0.35, 0.12],
      );
      for (var j = 0; j < pluck.length; j++) {
        pluck[j] *= _decay(j / _rate, 0.28);
      }
      // The first of each group of four falls a little louder.
      _mix(s, pluck, at: start + i * eighthS, gain: i % 4 == 0 ? 0.34 : 0.24);
    }
    // The bell on the first beat of the chord.
    final bell = _note(
      hz(chord.first + 48),
      2.5,
      attack: 0.003,
      release: 0.1,
      harmonics: const [1, 0.2],
    );
    for (var j = 0; j < bell.length; j++) {
      bell[j] *= _decay(j / _rate, 0.9);
    }
    _mix(s, bell, at: start, gain: 0.16);
  }
  // Fold what rings past the end onto the start.
  final loop = s.sublist(0, (total * _rate).round());
  for (var i = (total * _rate).round(); i < s.length; i++) {
    loop[i - (total * _rate).round()] += s[i];
  }
  return _peak(loop, 0.7, fadeOut: false);
}

/// [samples] scaled so that the loudest is [level] (1 is full scale), faded
/// out over its last 30 ms so that it ends without a click.
List<double> _peak(List<double> samples, double level, {bool fadeOut = true}) {
  final top = samples.fold<double>(0, (m, v) => math.max(m, v.abs()));
  final fade = (0.03 * _rate).round();
  return [
    for (var i = 0; i < samples.length; i++)
      samples[i] /
          (top == 0 ? 1 : top) *
          level *
          (fadeOut ? math.min(1, (samples.length - i) / fade) : 1),
  ];
}

/// A mono 16-bit PCM WAV file of [samples].
Uint8List _wav(List<double> samples) {
  final data = ByteData(44 + samples.length * 2);
  void text(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  text(8, 'WAVEfmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, _rate, Endian.little)
    ..setUint32(28, _rate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(
      44 + i * 2,
      (samples[i].clamp(-1, 1) * 32767).round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}
