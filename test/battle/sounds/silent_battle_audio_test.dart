import 'package:battle_team/battle/sounds/battle_audio.dart';
import 'package:battle_team/battle/sounds/sound_cue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(SilentBattleAudio, () {
    test('M7.14 plays nothing and lets go of nothing, without failing', () {
      const audio = SilentBattleAudio();

      expect(
        () => audio.play(const [SoundCue(Sound.victory)]),
        returnsNormally,
      );
      expect(() => audio.setAmbience(on: true), returnsNormally);
      expect(audio.dispose, returnsNormally);
    });
  });
}
