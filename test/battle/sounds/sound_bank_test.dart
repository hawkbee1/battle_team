import 'dart:io';

import 'package:battle_team/battle/sounds/sound_bank.dart';
import 'package:battle_team/battle/sounds/sound_cue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(SoundBank, () {
    test('a unit on foot moves with footsteps, a machine with an engine', () {
      for (final type in SoundBank.onFoot) {
        expect(SoundBank.fileOf(SoundCue(Sound.move, subject: type)), 'foot');
      }
      for (final type in ['tank', 'jeep', 'truck', 'artillery']) {
        expect(
          SoundBank.fileOf(SoundCue(Sound.move, subject: type)),
          'vehicle',
        );
      }
    });

    test('each weapon is heard as its kind of weapon', () {
      String of(String? weapon) =>
          SoundBank.fileOf(SoundCue(Sound.shot, subject: weapon));

      expect(of('rifle'), 'rifle');
      expect(of('machine_gun'), 'machine_gun');
      expect(of('anti_tank'), 'cannon');
      expect(of('anti_air'), 'cannon');
      expect(of('artillery'), 'cannon');
      expect(of('explosive'), 'blast');
      // A weapon this client does not know is a rifle.
      expect(of('plasma'), 'rifle');
      expect(of(null), 'rifle');
    });

    test('the other sounds have a file each', () {
      String of(Sound sound) => SoundBank.fileOf(SoundCue(sound));

      expect(of(Sound.injury), 'hit');
      expect(of(Sound.death), 'death');
      expect(of(Sound.victory), 'victory');
      expect(of(Sound.defeat), 'defeat');
    });

    test('the asset key is in the sounds folder', () {
      expect(
        SoundBank.assetOf(const SoundCue(Sound.injury)),
        'assets/sounds/hit.wav',
      );
    });

    test(
      'every sound a cue can ask for is in the files to load, and exists',
      () {
        final asked = {
          for (final sound in Sound.values)
            for (final subject in [
              null,
              'tank',
              'soldier',
              'machine_gun',
              'anti_tank',
              'explosive',
            ])
              SoundBank.fileOf(SoundCue(sound, subject: subject)),
        };

        expect(SoundBank.files, containsAll(asked));
        for (final file in SoundBank.files) {
          expect(
            File('assets/sounds/$file.wav').existsSync(),
            isTrue,
            reason: file,
          );
        }
      },
    );

    test('the volume is between 0 and 1, the end of the battle full', () {
      for (final sound in Sound.values) {
        final volume = SoundBank.volumeOf(SoundCue(sound));
        expect(volume, inInclusiveRange(0.1, 1));
      }
      expect(SoundBank.volumeOf(const SoundCue(Sound.victory)), 1);
      expect(
        SoundBank.volumeOf(const SoundCue(Sound.shot, subject: 'machine_gun')),
        lessThan(SoundBank.volumeOf(const SoundCue(Sound.shot))),
      );
      expect(
        SoundBank.volumeOf(const SoundCue(Sound.move, subject: 'tank')),
        lessThan(1),
      );
      expect(
        SoundBank.volumeOf(const SoundCue(Sound.move, subject: 'soldier')),
        lessThan(1),
      );
    });

    test('the end of the battle keeps its pitch, the rest varies a little', () {
      expect(SoundBank.pitchSpreadOf(const SoundCue(Sound.victory)), 0);
      expect(SoundBank.pitchSpreadOf(const SoundCue(Sound.defeat)), 0);
      expect(
        SoundBank.pitchSpreadOf(const SoundCue(Sound.shot)),
        greaterThan(0),
      );
    });
  });

  group(SoundGate, () {
    test('lets a kind through once in its gap', () {
      final gate = SoundGate();
      const t = Duration.zero;

      expect(gate.allow(Sound.shot, t), isTrue);
      expect(
        gate.allow(Sound.shot, t + const Duration(milliseconds: 39)),
        isFalse,
      );
      expect(
        gate.allow(Sound.shot, t + const Duration(milliseconds: 40)),
        isTrue,
      );
    });

    test('counts a held-back sound as not played: the gap runs from the last '
        'one that played', () {
      final gate = SoundGate();

      expect(gate.allow(Sound.shot, Duration.zero), isTrue);
      expect(gate.allow(Sound.shot, const Duration(milliseconds: 30)), isFalse);
      expect(gate.allow(Sound.shot, const Duration(milliseconds: 60)), isTrue);
    });

    test('keeps a gap for each kind', () {
      final gate = SoundGate();

      expect(gate.allow(Sound.shot, Duration.zero), isTrue);
      expect(gate.allow(Sound.death, Duration.zero), isTrue);
      expect(gate.allow(Sound.injury, Duration.zero), isTrue);
      expect(gate.allow(Sound.move, Duration.zero), isTrue);
    });

    test('never holds back the end of the battle', () {
      final gate = SoundGate();

      expect(gate.allow(Sound.victory, Duration.zero), isTrue);
      expect(gate.allow(Sound.victory, Duration.zero), isTrue);
      expect(gate.allow(Sound.defeat, Duration.zero), isTrue);
    });
  });
}
