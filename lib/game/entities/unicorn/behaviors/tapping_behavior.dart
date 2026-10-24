import 'package:audioplayers/audioplayers.dart';
import 'package:battle_team/game/game.dart';
import 'package:battle_team/gen/assets.gen.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_behaviors/flame_behaviors.dart';

class TappingBehavior extends Behavior<Unicorn>
    with TapCallbacks, HasGameReference<BattleTeam> {
  @override
  bool containsLocalPoint(Vector2 point) {
    return parent.containsLocalPoint(point);
  }

  @override
  Future<void> onTapDown(TapDownEvent event) async {
    if (parent.isAnimationPlaying()) {
      return;
    }
    game.counter++;
    parent.playAnimation();

    await game.effectPlayer.play(AssetSource(Assets.audio.effect));
  }
}
